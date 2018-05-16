import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "Hello, world!" example
//    router.get("/") { req in
//        return lwaButton
//    }
    router.get { req -> Future<View> in
        var context = [String: String]()
        context["LWA-CLIENTID"] = Environment.get("LWA-CLIENTID")
        context["LWA-CLIENTSECRET"] = Environment.get("LWA-CLIENTSECRET")
        context["SITE-URL"] = Environment.get("SITE-URL")
        return try req.view().render("home", context)
    }
    
    router.get("LwaResponse") { req -> String in
        let retVal = req.http.body.debugDescription
        return retVal
    }
    
    router.post("PostTest") { req -> String in
        let retText = "post test route"
        logger.info("Hit post test route.")
        return retText
    }
    
    let alexaController = AlexaController()
    let usersController = UsersController()
    let loginWithAmazonController = LoginWithAmazonController()
    try router.register(collection: alexaController)
    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
}
