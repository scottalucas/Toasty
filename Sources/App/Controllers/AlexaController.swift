//import Vapor
//import Fluent
//import CNIOHTTPParser
//
//struct AlexaController: RouteCollection {
//    let foo = Environment.get("FOO")
//    func boot(router: Router) throws {
//        let alexaRoutes = router.grouped("Alexa")
//        //        router.get("api", "acronyms", use: getAllHandler)
//        
//        
//        func helloHandler (_ req: Request) -> String {
//            debugPrint ("Hit on the post.")
//            return "Hello! You got Alexa controller! Foo is \(foo ?? "Not found")"
//    }
//        func discoveryHandler (_ req: Request) throws -> (AlexaTestMessage) {
//            let msgJSON = req.http.body.debugDescription
//            logger.debug("Request in discovery handler: \(req.debugDescription)")
//            logger.debug("JSON in discovery hander: \(msgJSON)")
//            return AlexaTestMessage(testMessage: msgJSON)
//        }
//
//        
//        alexaRoutes.get(use: helloHandler)
//        alexaRoutes.post("Discovery", use: discoveryHandler)
//    }
//    
//}

