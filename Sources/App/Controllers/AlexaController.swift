import Vapor
import Fluent
import FluentPostgreSQL

struct AlexaController: RouteCollection {
    func boot(router: Router) throws {
        let alexaRoutes = router.grouped(ToastyAppRoutes.alexa.root)
        
        func helloHandler (_ req: Request) -> String {
            debugPrint ("Hit on the post.")
            return "Hello! You got Alexa controller!"
        }
        
        func discoveryHandler (_ req: Request) throws -> Future<Response> {
            guard
                let discoveryRequest:AlexaDiscoveryRequest = try? req.content.syncDecode(AlexaDiscoveryRequest.self),
                let userRequestToken = discoveryRequest.directive.payload.scope?.token
                else {
                    logger.error("Failed to decode Alexa discovery request.")
                    throw AlexaError(.couldNotDecodeDiscovery, file: #file, function: #function, line: #line)
            }
            
            let msgId = discoveryRequest.directive.header.messageId
            let msgJSON = req.http.body.debugDescription
//            logger.debug("Request in discovery handler: \(req.debugDescription)")
//            logger.debug("JSON in discovery hander: \(msgJSON)")
            
            return try User.getAmazonAccount(usingToken: userRequestToken, on: req)
                .flatMap(to: [Fireplace].self) { acct in
                    return try AlexaController.getAssociatedFireplaces(using: acct, on: req)
                }.flatMap (to: Response.self) { fireplaces in
                    return try AlexaDiscoveryResponse(msgId: msgId, sendBack: fireplaces).encode(for: req)
                }.catchFlatMap { error in
                    switch error {
                        case let err as ToastyError:
                            logger.error(err.extendedDescription)
                        default:
                            logger.error(error.localizedDescription)
                    }
                    guard let response = try? AlexaDiscoveryResponse(msgId: msgId, sendBack: []).encode(for: req) else {throw error}
                    return response
            }
        }
        
        func powerControllerHandler(_ req: Request) throws ->
            Future<Response> {
                guard
                    let inboundMessage:AlexaMessage = try? req.content.syncDecode(AlexaMessage.self),
                    let endpoint: AlexaEndpoint = inboundMessage.directive.endpoint,
                    let scope = endpoint.scope
                    else {
                        throw AlexaError(.couldNotDecodePowerControllerDirective, file: #file, function: #function, line: #line)
                }
                let userRequestToken = scope.token
                let correlationToken = inboundMessage.directive.header.correlationToken
                let messageId = inboundMessage.directive.header.messageId
                
                let action:ImpFireplaceAction
                do {
                    action = try ImpFireplaceAction(action: inboundMessage.directive.header.name.rawValue)
                } catch {
                    let error = ImpError.init(.fireplaceUnavailable, file: #file, function: #function, line: #line)
                    do {
                        return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidDirective, message: error.extendedDescription)
                            .encode(for: req)
                    } catch {
                        throw error
                    }
                }
                
                guard
                    let targetFireplaceId = UUID.init(endpoint.endpointId)
                    else {
                        do {
                            let error = AlexaError(.couldNotRetrieveFireplace)
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidDirective, message: error.extendedDescription)
                                .encode(for: req)
                        } catch {
                            throw error
                        }
                }
                
                return try User.getAmazonAccount(usingToken: userRequestToken, on: req)
                    .flatMap(to: [Fireplace].self) { account in
                        return try AlexaController.getAssociatedFireplaces(using: account, on: req)
                    }.flatMap(to: ImpFireplaceAck.self) { fireplaces in
                        let optFireplace = fireplaces
                            .filter { $0.id != nil }
                            .filter { $0.id! == targetFireplaceId }
                            .first
                        guard let fireplace = optFireplace else {throw AlexaError(.childFireplacesNotFound, file: #file, function: #function, line: #line)}
                        return FireplaceManagementController.action(action, executeOn: fireplace.controlUrl, on: req)
                    }.flatMap (to: Response.self) { impStatus in
                        switch impStatus.ack {
                        case .acceptedOn, .acceptedOff:
                            let props = [ AlexaProperty(namespace: .power, name: .power, value: impStatus.ack.rawValue, time: Date(), uncertainty: 500), AlexaProperty(endpointHealth: .ok)]
                            let header = AlexaHeader(namespace: .basic, name: .response, payloadVer: .latest, msgId: messageId, corrToken: correlationToken)
                            let scope = AlexaScope(token: userRequestToken)
                            let endpoint = AlexaEndpoint(using: endpoint.endpointId, scope: scope, cookie: nil)
                            return try AlexaResponse(context: AlexaContext(properties: props), event: AlexaEvent(header: header, endpoint: endpoint, payload: AlexaPayload()))
                                .encode(for: req)
                        case .notAvailable:
                            let err = ImpError(.fireplaceUnavailable, file: #file, function: #function, line: #line)
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .endpointUnreachable, message: err.extendedDescription)
                                .encode(for: req)
                        case .rejected:
                            let err = ImpError(.operationNotSupported, file: #file, function: #function, line: #line)
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidDirective, message: err.extendedDescription)
                                .encode(for: req)
                        }
                    }.catchFlatMap { error in
                        switch error {
                        case let err as ImpError:
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .endpointUnreachable, message: err.extendedDescription)
                                .encode(for: req)
                        case let err as LoginWithAmazonError:
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidCredential, message: err.extendedDescription)
                                .encode(for: req)
                        case let err as AlexaError:
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidDirective, message: err.extendedDescription)
                                .encode(for: req)
                        default:
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidDirective, message: "The fireplace can't process your request right now.")
                                .encode(for: req)
                        }
                }
        }
       
        func reportStateHandler(_ req: Request) throws -> Future<Response> {
            
        }
        
        alexaRoutes.get(use: helloHandler)
        alexaRoutes.post("Discovery", use: discoveryHandler)
        alexaRoutes.get("Discovery", use: discoveryHandler)
        alexaRoutes.get("ReportState", use: reportStateHandler)
        alexaRoutes.post("PowerController", use: powerControllerHandler)
        }
        
        //*******************************************************************************
        //helper functions, not route responders
        //*******************************************************************************
        
    static func getAssociatedFireplaces(using amazonAccount: AmazonAccount, on req: Request) throws -> Future<[Fireplace]> {
        return try amazonAccount.user.query(on: req).first()
            //            }.catchFlatMap { err in
            //                throw AlexaError(.failedToLookupUser, file: #file, function: #function, line: #line)
            .flatMap (to: [Fireplace].self) { optUser in
                guard let user = optUser else {
                    throw AlexaError(.noCorrespondingToastyAccount, file: #file, function: #function, line: #line)
                }
                return try user.fireplaces.query(on: req).all()
        }
    }
}
