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
			let logger = try? req.sharedContainer.make(Logger.self)
			
			guard let discoveryRequest:AlexaMessage = try? req.content.syncDecode(AlexaMessage.self)
				else {
					logger?.error("Failed to decode Alexa discovery request.")
					throw AlexaError(.couldNotDecodeDiscovery, file: #file, function: #function, line: #line)
			}
			
			let msgId = discoveryRequest.directive.header.messageId
			
			guard
				let userRequestToken = discoveryRequest.directive.payload.scope?.token
				else {
					logger?.error("Failed to find token in discovery request.")
					return try! AlexaDiscoveryResponse(msgId: msgId, sendBack: []).encode(for: req)
			}
			
			
			return AmazonAccount.getAmazonAccount(usingToken: userRequestToken, on: req)
				.flatMap(to: Response.self) { acctResult in
					switch acctResult {
					case .success(let acct):
						return try acct.fireplaces
							.query(on: req)
							.all()
							.flatMap(to: Response.self) { fireplaces in
								return try! AlexaDiscoveryResponse(msgId: msgId, sendBack: fireplaces).encode(for: req)
						}
					case .failure(let err):
						logger?.error(err.description)
						return try AlexaDiscoveryResponse(msgId: msgId, sendBack: []).encode(for: req)
					}
			}
		}
		
		func powerControllerHandler(_ req: Request) throws ->
			Future<Response> {
				let logger = try? req.sharedContainer.make(Logger.self)

				guard let controlRequest = try? req.content.syncDecode(AlexaMessage.self)
					else { throw Abort(.notFound) }

				guard let endpointId = controlRequest.directive.endpoint?.endpointId,
					let userRequestToken = controlRequest.directive.endpoint?.scope?.token,
					let action = ImpFireplaceAction(action: controlRequest.directive.header.name.rawValue)
					else { return try AlexaErrorResponse(requestedVia: controlRequest, errType: .invalidDirective, message: "Could not decode endpoint. Id: \(controlRequest.directive.endpoint?.endpointId ?? "not found"), Token: \(controlRequest.directive.endpoint?.scope?.token ?? "not found"), Action: \(controlRequest.directive.header.name.rawValue)").encode(for: req) }
				
				var fireplace: Future<Fireplace?> { return Fireplace.find(endpointId, on: req) }
				
				var account: Future<Result<AmazonAccount, LoginWithAmazonError>> { return AmazonAccount.getAmazonAccount(usingToken: userRequestToken, on: req) }
				
				return flatMap(to: Response.self, fireplace, account) { optFp, acctResult in
					guard let fp = optFp else { return try AlexaErrorResponse(requestedVia: controlRequest, errType: .noSuchEndpoint, message: "Endpoint \(optFp.debugDescription) not found.").encode(for: req) }
					
					switch acctResult {
					case .success(let acct):
						return acct.fireplaces
							.isAttached(fp, on: req)
							.flatMap (to: Response.self) { found in
								if found {
									return try FireplaceManagementController
										.action(action, forFireplace: fp, on: req)
										.flatMap (to: Response.self) { impResult in
											logger?.info ("Imp status: \(impResult)")
											switch impResult {
											case .success (let actionResult):
//												let impStatus = actionResult.ack
												switch actionResult.ack {
												case .acceptedOn, .acceptedOff:
													return try AlexaPowerControllerResponse.init(requestedVia: controlRequest, fireplaceState: actionResult)
													.encode(for: req)
												case .rejected:
													logger?.error(ErrorFormat.forError(error: ImpError(.operationNotSupported, file: #file, function: #function, line: #line)))
													return try AlexaErrorResponse(requestedVia: controlRequest, errType: .notInOperation, message: "Fireplace \(fp.id ?? "id not found") rejected request.").encode(for: req)
												case .notAvailable, .updating:
													logger?.error(ErrorFormat.forError(error: ImpError(.fireplaceOffline, file: #file, function: #function, line: #line)))
													return try AlexaErrorResponse(requestedVia: controlRequest, errType: .endpointUnreachable, message: "Fireplace \(fp.id ?? "id not found") not available.").encode(for: req)
												}
											case .failure (let err):
												return try err.alexaError(forAlexaMessage: controlRequest).encode(for: req)
											}
									}

								} else {
									return try AlexaErrorResponse(requestedVia: controlRequest, errType: .noSuchEndpoint, message: "No fireplace with ID \(fp.id ?? "not found") registered with account \(acct.id ?? "id not found").").encode(for: req)
								}
						}
					case .failure(let failure):
						return try failure.alexaError(forAlexaMessage: controlRequest).encode(for: req)
					}
		}
		}
		
		func reportStateHandler(_ req: Request) throws -> Future<Response> {
			let logger = try? req.sharedContainer.make(Logger.self)
			let stateReportRequest = try req.content.syncDecode(AlexaMessage.self)
			guard
				let endpointId = stateReportRequest.directive.endpoint?.endpointId
				else {
					return try AlexaErrorResponse(requestedVia: stateReportRequest, errType: .invalidDirective, message: "Endpoint id not found in directive.").encode(for: req)
			}
			
			return Fireplace.find(endpointId, on: req)
				.flatMap (to: Result<ImpFireplaceStatus, ImpError>.self) { optFireplace in
					guard let fireplace = optFireplace else {
						throw AlexaErrorResponse(requestedVia: stateReportRequest, errType: .noSuchEndpoint, message: "Fireplace not found.")
					}
					return try FireplaceManagementController.action(ImpFireplaceAction(action: .update), forFireplace: fireplace, on: req)
				}.flatMap (to: Response.self) { status in
					switch status {
					case .success (let status):
						var rpt = try AlexaStateReport(stateRequest: stateReportRequest)
						rpt.updateProperties(fireplaceStatus: status)
						return try rpt.encode(for: req)
					case .failure (let error):
						throw error.alexaError(forAlexaMessage: stateReportRequest)
					}
				}.catchFlatMap { error in
					logger?.error(ErrorFormat.forError(error: error))
					switch error {
					case let e as ResponseEncodable:
						return try e.encode(for: req)
					default:
						throw Abort(.notFound)
					}
			}
		}
		
		alexaRoutes.get(use: helloHandler)
		alexaRoutes.post("Discovery", use: discoveryHandler)
		alexaRoutes.post(use: reportStateHandler)
		alexaRoutes.post("PowerController", use: powerControllerHandler)
	}
}
