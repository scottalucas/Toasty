import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "Hello, world!" example
//    router.get("/") { req in
//        return lwaButton
//    }
    let lwaClientId = Environment.get("LWA-CLIENTID") ?? "Client ID not found"
    logger.info("Client id: \(lwaClientId)")
    let lwaClientSecret = Environment.get("LWA-CLIENTSECRET") ?? "Client secret not found"
    logger.info("Client sec: \(lwaClientSecret)")
    let siteUrl = Environment.get("SITE-URL") ?? "Site URL not found"
    logger.info("Site url: \(siteUrl)")
    let foo = Environment.get("FOO") ?? "FOO not found"

    router.get { req -> Future<View> in
        var context = [String: String]()
        context["LWA-CLIENTID"] = lwaClientId
        context["LWA-CLIENTSECRET"] = lwaClientSecret
        context["SITE-URL"] = siteUrl
        context["foo"] = foo
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
