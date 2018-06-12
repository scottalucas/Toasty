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
        
        func discoveryHandler (_ req: Request) throws -> Future<AlexaDiscoveryResponse> {
            guard
                let discoveryRequest:AlexaDiscoveryRequest = try? req.content.syncDecode(AlexaDiscoveryRequest.self),
                let userRequestToken = discoveryRequest.directive.payload.scope?.token
                else {
                    logger.error("Failed to decode Alexa discovery request.")
                    throw AlexaError(id: .couldNotDecodeDiscovery, file: #file, function: #function, line: #line)
            }
            
            let msgId = discoveryRequest.directive.header.messageId
            let corrToken = discoveryRequest.directive.header.correlationToken ?? "No correlation token."
            
            let associatedAmazonAccount:Future<AmazonAccount> = try {
                do {
                    return try User.getAmazonAccount(usingToken: userRequestToken, on: req)
                } catch {
                    logger.error("Failed retrieve user account during Alexa discovery request.")
                    throw AlexaError(id: .couldNotRetrieveUserAccount, file: #file, function: #function, line: #line)
                }
                } ()
            
            
            let associatedFireplaces:Future<[Fireplace]> = {
                do {
                    return try getAssociatedFireplaces(using: associatedAmazonAccount, on: req)
                } catch {
                    if let err = error as? AlexaError {
                        logger.error("\(err.description)\n\tfile: \(err.file ?? "not provided.")\n\tfunction: \(err.function ?? "not provided.")\n\tline: \(err.line.debugDescription)")
                    } else {
                        logger.error("Failed to find fireplaces during Alexa discovery request.")
                    }
                    return Future.map(on: req) { [] }
                }
            } ()
            
            let msgJSON = req.http.body.debugDescription
            logger.debug("Request in discovery handler: \(req.debugDescription)")
            logger.debug("JSON in discovery hander: \(msgJSON)")
            
            return associatedFireplaces
                .map (to: AlexaDiscoveryResponse.self) { fireplaces in
                    return AlexaDiscoveryResponse(msgId: msgId, corrToken: corrToken, sendBack: fireplaces)
            }
        }
        
        func powerControllerHandler(_ req: Request) throws ->
            Future<Response> {
                guard
                    let inboundMessage:AlexaMessage = try? req.content.syncDecode(AlexaMessage.self),
                    let endpoint: AlexaEndpoint = inboundMessage.directive.endpoint,
                    let userRequestToken = endpoint.scope?.token
                    else {
                        throw AlexaError(id: .couldNotDecodePowerControllerDirective, file: #file, function: #function, line: #line)
                }
                
                let correlationToken = inboundMessage.directive.header.correlationToken
                let messageId = inboundMessage.directive.header.messageId
                let action:ImpFireplaceAction = try ImpFireplaceAction(action: inboundMessage.directive.header.name)
                
                guard
                    let targetFireplaceId = UUID.init(endpoint.endpointId)
                    else {
                        return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidDirective, message: "Toasty server could not understand the message from Alexa.")
                            .encode(for: req)
                }
                
                let associatedAmazonAccount:Future<AmazonAccount> = try User.getAmazonAccount(usingToken: userRequestToken, on: req)
                
                let associatedFireplaces:Future<[Fireplace]> = try getAssociatedFireplaces(using: associatedAmazonAccount, on: req)
                
                return associatedFireplaces
                    .flatMap(to: ImpFireplaceAck.self) { fireplaces in
                        let optFireplace = fireplaces
                            .filter { $0.id != nil }
                            .filter { $0.id! == targetFireplaceId }
                            .first
                        guard let fireplace = optFireplace else {throw ImpError(id: .childFireplacesNotFound, file: #file, function: #function, line: #line)}
                        return FireplaceManagementController.action(action, executeOn: fireplace.controlUrl, on: req)
                    }.catchFlatMap { impErr in
                        if let err = impErr as? ImpError {
                            logger.error("\(err.description)\n\tfile: \(err.file ?? "not provided.")\n\tfunction: \(err.function ?? "not provided.")\n\tline: \(err.line.debugDescription)")
                        } else {
                            logger.error("Failed to execute action for fireplace request.")
                        }
                        return Future.map(on: req) { ImpFireplaceAck(ack: .notAvailable) }
                    }.flatMap (to: Response.self) { impStatus in
                        switch impStatus.ack {
                        case .acceptedOn, .acceptedOff:
                            let props = [ AlexaProperty(namespace: .power, name: "powerState", value: impStatus.ack.rawValue, time: Date(), uncertainty: 500) ] //currently returns wrong status, fix.
                            let header = AlexaHeader(namespace: AlexaEnvironment.SmartHomeInterface.fireplace.rawValue, name: impStatus.ack == .acceptedOn ? "ON" : "OFF", payloadVersion: AlexaEnvironment.interfaceVersion, messageId: messageId, correlationToken: correlationToken)
                            let scope = AlexaScope(token: userRequestToken)
                            let endpoint = AlexaEndpoint(using: endpoint.endpointId, scope: scope, cookie: nil)
                            return try AlexaResponse(context: AlexaContext(properties: props), event: AlexaEvent(header: header, endpoint: endpoint, payload: AlexaPayload()))
                                .encode(for: req)
                        case .notAvailable:
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .endpointUnreachable, message: "The fireplace isn't available.")
                                .encode(for: req)
                        case .rejected:
                            return try AlexaErrorResponse(msgId: messageId, corrToken: correlationToken, endpointId: endpoint.endpointId, accessToken: userRequestToken, errType: .invalidDirective, message: "The fireplace can't process your request right now.")
                                .encode(for: req)
                        }
                }
        }
        
        alexaRoutes.get(use: helloHandler)
        alexaRoutes.post("Discovery", use: discoveryHandler)
        alexaRoutes.get("Discovery", use: discoveryHandler)
        alexaRoutes.post("PowerController", use: powerControllerHandler)
        
    }
    
    //*******************************************************************************
    //helper functions, not route responders
    //*******************************************************************************
    
    func getAssociatedFireplaces(using amazonAccount: Future<AmazonAccount>, on req: Request) throws -> Future<[Fireplace]> {
        return amazonAccount
            .flatMap (to: User?.self) { azAcct in
                return try azAcct.user.query(on: req).first()
            }.catchFlatMap { err in
                throw AlexaError(id: .failedToLookupUser, file: #file, function: #function, line: #line)
            }.flatMap (to: [Fireplace].self) { optUser in
                guard let user = optUser else {
                    throw AlexaError(id: .noCorrespondingToastyAccount, file: #file, function: #function, line: #line)
                }
                return try user.fireplaces.query(on: req).all()
            }.catchFlatMap { err in
                throw AlexaError(id: .childFireplacesNotFound, file: #file, function: #function, line: #line)
        }
    }
}
