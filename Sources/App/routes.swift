import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "Hello, world!" example
//    router.get("/") { req in
//        return lwaButton
//    }ProcessInfo.processInfo.environment[key]




//    let lwaClientSecret = Environment.get("LWA-CLIENTSECRET") ?? "Client secret not found"
//    logger.info("Client sec: \(lwaClientSecret)")
//    let siteUrl = Environment.get("SITE-URL") ?? "Site URL not found"
//    logger.info("Site url: \(siteUrl)")

    router.get { req -> Future<View> in
        logger.info("ONE")

        let lwaClientId = Environment.get("LWACLIENTID") ?? "Client ID not found"
        let lwaClientIdRaw = ProcessInfo.processInfo.environment["LWACLIENTID"] ?? "Client ID not found"
        let lwaClientId2 = Environment.get("LWACLIENTSECRET") ?? "Client secret not found"
        let lwaClientId2Raw = ProcessInfo.processInfo.environment["LWACLIENTSECRET"] ?? "Client secret not found"
        let foo = Environment.get("FOO") ?? "FOO not found"
        let fooRaw = ProcessInfo.processInfo.environment["FOO"] ?? "Foo not found"
        var context = [String: String]()
        logger.info("TWO")
        context["lwaClientId"] = lwaClientId
        context["lwaClientIdRaw"] = lwaClientIdRaw
        context["lwaClientId2"] = lwaClientId2
        context["lwaClientId2Raw"] = lwaClientId2Raw
        context["foo"] = foo
        context["fooRaw"] = fooRaw
        context["foo"] = foo
        logger.info("THREE")
        logger.info("Client id: \(lwaClientId)")
        logger.info("Client id raw: \(lwaClientIdRaw)")
        logger.info("Client id 2: \(lwaClientId2)")
        logger.info("Client id 2 raw: \(lwaClientId2Raw)")
        logger.info("foo: \(foo)")
        logger.info("foo raw: \(fooRaw)")
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
