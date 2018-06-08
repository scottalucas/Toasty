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
            let discoveryRequest:AlexaDiscoveryRequest = try req.content.syncDecode(AlexaDiscoveryRequest.self)
            guard let userRequestToken = discoveryRequest.directive.payload.scope?.token else {
                throw Abort(.notFound, reason: "Could not retrieve user ID from Amazon.")
            }
            let associatedAmazonAccount:Future<AmazonAccount> = try User.getAmazonAccount(usingToken: userRequestToken, on: req)
            
            let associatedFireplaces:Future<[Fireplace]> = getAssociatedFireplaces(using: associatedAmazonAccount, on: req)
            
            let msgJSON = req.http.body.debugDescription
            logger.debug("Request in discovery handler: \(req.debugDescription)")
            logger.debug("JSON in discovery hander: \(msgJSON)")
            
            return associatedFireplaces
                .map (to: AlexaDiscoveryResponse.self) { fireplaces in
                    guard let discoveryResponse = AlexaDiscoveryResponse(msgId: discoveryRequest.directive.header.messageId, sendBack: fireplaces) else {throw Abort(.notFound, reason: "Could not generate the discovery response.")}
                    return discoveryResponse
            }
        }
        
        func powerControllerHandler(_ req: Request) throws ->
            Future<Response> {
                guard
                    let inboundMessage:AlexaMessage = try? req.content.syncDecode(AlexaMessage.self),
                    let endpoint: AlexaEndpoint = inboundMessage.directive.endpoint,
                    let targetFireplaceId = UUID.init(endpoint.endpointId),
                    let userRequestToken = endpoint.scope?.token
                    else { throw Abort(.notFound, reason: "Failed to decode inbound Alexa PowerController message.") }
                let action:ImpFireplaceAction = try ImpFireplaceAction(action: inboundMessage.directive.header.name)
                let correlationToken = inboundMessage.directive.header.correlationToken
                let messageId = inboundMessage.directive.header.messageId
                
                let associatedAmazonAccount:Future<AmazonAccount> = try User.getAmazonAccount(usingToken: userRequestToken, on: req)
                
                let associatedFireplaces:Future<[Fireplace]> = getAssociatedFireplaces(using: associatedAmazonAccount, on: req)
                
                return associatedFireplaces
                    .flatMap(to: ImpFireplaceAck.self) { fireplaces in
                        let optFireplace = fireplaces
                            .filter ({
                                if $0.id == nil {
                                    return false
                                } else if $0.id! == targetFireplaceId {
                                        return true
                                } else {
                                        return false
                                }
                            })
                            .first
                        guard let fireplace = optFireplace else {return Future.map(on: req) {ImpFireplaceAck()}}
                        return FireplaceManagementController.action(action, executeOn: fireplace.controlUrl, on: req)
                    }.flatMap (to: Response.self) { status in
                        return try AlexaFireplaceDirectiveResponse(impStatus: status, msgId: messageId, corrToken: correlationToken, accToken: userRequestToken, endptId: endpoint.endpointId, context: req)
                    }
        }
        
        alexaRoutes.get(use: helloHandler)
        alexaRoutes.post("Discovery", use: discoveryHandler)
        alexaRoutes.get("Discovery", use: discoveryHandler)
        alexaRoutes.post("PowerController", use: powerControllerHandler)

    }
}

//*******************************************************************************
//helper functions, not route responders
//*******************************************************************************

func getAssociatedFireplaces(using amazonAccount: Future<AmazonAccount>, on req: Request) -> Future<[Fireplace]> {
    //    do {
    return amazonAccount
        .flatMap (to: User?.self) { azAcct in
            do {
                return try azAcct.user.query(on: req).first()
            } catch {
                throw Abort(.notFound, reason: "User account lookup failed.")
            }
        }.flatMap (to: [Fireplace].self) { optUser in
            guard let user = optUser else {throw Abort(.notFound, reason: "No user associated with provided Amazon account.")}
            do {
                return try user.fireplaces.query(on: req).all()
            } catch {
                throw Abort(.notFound, reason: "Fireplace child lookup failed.")
            }
    }
}

func AlexaFireplaceDirectiveResponse (impStatus: ImpFireplaceAck, msgId: String, corrToken: String?, accToken: String, endptId: String, context req: Request) throws -> Future<Response> {
    switch impStatus.ack {
    case .accepted:
        let props = [ AlexaProperty(namespace: .power, name: "powerState", value: impStatus.ack.rawValue, time: Date(), uncertainty: 500) ] //currently returns wrong status, fix.
        let header = AlexaHeader(namespace: AlexaEnvironment.SmartHomeInterface.fireplace.rawValue, name: "Response", payloadVersion: AlexaEnvironment.interfaceVersion, messageId: msgId, correlationToken: corrToken)
        let scope = AlexaScope(token: accToken)
        let endpoint = AlexaEndpoint(using: endptId, scope: scope, cookie: nil)
        return try AlexaResponse(context: AlexaContext(properties: props), event: AlexaEvent(header: header, endpoint: endpoint, payload: AlexaPayload()))
        .encode(for: req)
    default:
        return try AlexaError(msgId: msgId, corrToken: corrToken ?? "no corr token", endpoint: endptId, errType: .endpointUnreachable, message: "Fireplace did not respond.")
        .encode(for: req) //fix this error message
    }
}
