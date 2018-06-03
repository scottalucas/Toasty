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
        func discoveryHandler (_ req: Request) throws -> (AlexaTestMessage) {
            let discoveryRequest:AlexaDiscoveryRequest = try req.content.syncDecode(AlexaDiscoveryRequest.self)
            guard let userRequestToken = discoveryRequest.directive.payload.scope?.token else {
                throw Abort(.notFound, reason: "Could not retrieve user ID from Amazon.")
            }
            let associatedAmazonAccount:Future<AmazonAccount> = try User.getAmazonAccount(usingToken: userRequestToken, on: req)
            
            let associatedFireplaces:Future<[Fireplace]> = getAssociatedFireplaces(for: associatedAmazonAccount, on: req)
            
            let msgJSON = req.http.body.debugDescription
            logger.debug("Request in discovery handler: \(req.debugDescription)")
            logger.debug("JSON in discovery hander: \(msgJSON)")
            return AlexaTestMessage(testMessage: msgJSON)
        }

        
        alexaRoutes.get(use: helloHandler)
        alexaRoutes.post("Discovery", use: discoveryHandler)
        alexaRoutes.get("Discovery", use: discoveryHandler)

    }
    
    //*******************************************************************************
    //helper functions, not route responders
    //*******************************************************************************

    func getAssociatedFireplaces(for amazonAccount: Future<AmazonAccount>, on req: Request) -> Future<[Fireplace]> {
        return amazonAccount
            .flatMap (to: [Fireplace].self) { acct in
                return try acct.fireplaces.query(on: req).all()
            }
    }
    
}

