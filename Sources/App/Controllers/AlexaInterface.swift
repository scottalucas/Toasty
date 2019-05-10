import Vapor
import Fluent
import FluentPostgreSQL

struct AlexaController: RouteCollection {
	func boot(router: Router) throws {
		let alexaRoutes = router.grouped(ToastyServerRoutes.Alexa.root)
		
		func helloHandler (_ req: Request) throws -> String {
			let logger = try req.sharedContainer.make(Logger.self)
			logger.debug ("Hit on the post.")
			return "Hello! You got Alexa controller!"
		}
		
		func discoveryHandler (_ req: Request) throws -> Future<Response> {
			let logger = try req.sharedContainer.make(Logger.self)
			guard
				let discoveryRequest:AlexaMessage = try? req.content.syncDecode(AlexaMessage.self),
				let userRequestToken = discoveryRequest.directive.payload.scope?.token
				else {
					logger.error("Failed to decode Alexa discovery request.")
					throw AlexaError(.couldNotDecodeDiscovery, file: #file, function: #function, line: #line)
			}
			
			let msgId = discoveryRequest.directive.header.messageId
			//            let msgJSON = req.http.body.debugDescription
			//            logger.debug("Request in discovery handler: \(req.debugDescription)")
			//            logger.debug("JSON in discovery hander: \(msgJSON)")
			
			return try AmazonAccount.getAmazonAccount(usingToken: userRequestToken, on: req)
				.flatMap(to: [Fireplace].self) { acct in
					return try acct.fireplaces.query(on: req).all()
				}.flatMap (to: Response.self) { fireplaces in
					return try AlexaDiscoveryResponse(msgId: msgId, sendBack: fireplaces).encode(for: req)
				}.catchFlatMap { error in
					logger.error(ErrorFormat.forError(error: error))
					guard let response = try? AlexaDiscoveryResponse(msgId: msgId, sendBack: []).encode(for: req) else {throw error}
					return response
			}
		}
		
		func powerControllerHandler(_ req: Request) throws ->
			Future<Response> {
				let logger = try req.sharedContainer.make(Logger.self)
				guard
					let inboundMessage:AlexaMessage = try? req.content.syncDecode(AlexaMessage.self),
					let endpoint: AlexaEndpoint = inboundMessage.directive.endpoint,
					let scope = endpoint.scope
					else {
						let err = AlexaError(.couldNotDecodePowerControllerDirective, file: #file, function: #function, line: #line)
						logger.error(ErrorFormat.forError(error: err))
						throw err
				}
				
				let userRequestToken = scope.token
				let action:ImpFireplaceAction
				do {
					action = try ImpFireplaceAction(action: inboundMessage.directive.header.name.rawValue)
				} catch {
					logger.error(ErrorFormat.forError(error: error))
					let retVal = try AlexaPowerControllerResponse.init(requestedVia: inboundMessage, fireplaceState: ImpFireplaceStatus())
					let retValEnc = try! retVal.encode(for: req)
					return retValEnc
				}
				
				return try AmazonAccount.getAmazonAccount(usingToken: userRequestToken, on: req)
					.flatMap(to: [Fireplace].self) { account in
						return try account.fireplaces.query(on: req).all()
					}.flatMap(to: Fireplace?.self) { fireplaces in
						print ("Fireplaces: \(fireplaces)")
						let ids = fireplaces.map{ $0.deviceid }
						guard ids.contains(endpoint.endpointId) else {return req.future(nil)}
						return Fireplace.find(endpoint.endpointId, on: req)
					}.flatMap(to: ImpFireplaceStatus.self) { optFireplace in
						guard let fireplace = optFireplace else {throw AlexaError(.childFireplacesNotFound, file: #file, function: #function, line: #line)}
						return try FireplaceManagementController.action(action, executeOn: fireplace, on: req)
					}.flatMap (to: Response.self) { impStatus in
						print ("Imp status: \(impStatus)")
						switch impStatus.ack {
						case .acceptedOn, .acceptedOff:
							return try AlexaPowerControllerResponse.init(requestedVia: inboundMessage, fireplaceState: impStatus)
								.encode(for: req)
						case .rejected, .notAvailable:
							logger.error(ErrorFormat.forError(error: ImpError(.operationNotSupported, file: #file, function: #function, line: #line)))
							return try AlexaPowerControllerResponse.init(requestedVia: inboundMessage, fireplaceState: ImpFireplaceStatus())
								.encode(for: req)
						}
					}.catchFlatMap { error in
						logger.error(ErrorFormat.forError(error: error))
						return try AlexaPowerControllerResponse.init(requestedVia: inboundMessage, fireplaceState: ImpFireplaceStatus())
							.encode(for: req)
				}
		}
		
		func reportStateHandler(_ req: Request) throws -> Future<Response> {
			let logger = try req.sharedContainer.make(Logger.self)
			guard
				let stateReportRequest: AlexaMessage = try? req.content.syncDecode(AlexaMessage.self)
				else {
					let err = AlexaError.init(.couldNotDecodeStatusReport, file: #file, function: #function, line: #line)
					logger.error(ErrorFormat.forError(error: err))
					throw err
			}
			guard
				let endpointId = stateReportRequest.directive.endpoint?.endpointId
				else {
					let err = AlexaError.init(.couldNotRetrieveFireplace, file: #file, function: #function, line: #line)
					logger.error(ErrorFormat.forError(error: err))
					return try AlexaPowerControllerResponse.init(requestedVia: stateReportRequest, fireplaceState: ImpFireplaceStatus())
						.encode (for: req)
			}
			guard
				var finalReport = AlexaStateReport(endpointId, stateRequest: stateReportRequest)
				else {
					let err = AlexaError.init(.couldNotEncode, file: #file, function: #function, line: #line)
					logger.error(ErrorFormat.forError(error: err))
					return try AlexaPowerControllerResponse.init(requestedVia: stateReportRequest, fireplaceState: ImpFireplaceStatus())
						.encode (for: req)
			}
			
			return Fireplace.query(on: req)
				.filter(\.deviceid == endpointId)
				.first()
				.flatMap (to: ImpFireplaceStatus.self) { optFireplace in
					guard let fireplace = optFireplace else {
						throw AlexaError.init(.couldNotRetrieveFireplace, file: #file, function: #function, line: #line)
					}
					guard let rpt = AlexaStateReport.init(forFireplace: fireplace, stateRequest: stateReportRequest) else {
						throw AlexaError(.couldNotDecodeStatusReport, file: #file, function: #function, line: #line)
					}
					finalReport = rpt
					return try FireplaceManagementController.action(ImpFireplaceAction(action: .update), executeOn: fireplace, on: req)
				}.flatMap (to: Response.self) { status in
					finalReport.updateProperties(fireplaceStatus: status)
					return try finalReport.encode(for: req)
				}.catchFlatMap { error in
					logger.error(ErrorFormat.forError(error: error))
					finalReport.updateProperties(fireplaceStatus: .init())
					do { return try finalReport.encode(for: req)
					} catch {
						throw error
					}
			}
		}
		
		alexaRoutes.get(use: helloHandler)
		alexaRoutes.post("Discovery", use: discoveryHandler)
		alexaRoutes.post(use: reportStateHandler)
		alexaRoutes.post("PowerController", use: powerControllerHandler)
	}
	
	//*******************************************************************************
	//helper functions, not route responders
	//*******************************************************************************
	//
	//    static func getFireplaces(forAmazonAccount acct: AmazonAccount, on req: Request) throws -> Future<[Fireplace]> {
	//
	//	guard let azId = acct.id
	//		else { return req.future(Array<Fireplace>.init()) }
	//
	//	return Fireplace
	//		.query(on: req)
	//		.join(\Fireplace.id, to: \AlexaFireplace.parentFireplaceId)
	//		.filter(\AlexaFireplace.parentAmazonAccountId == azId)
	//		.all()
	//    }
}
