import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
//    let logger = PrintLogger()
    logger.info("Starting main router")
//    router.get { req -> Future<View> in
//        var context = [String: String]()
//        context["LWA-CLIENTID"] = Environment.get("LWACLIENTID") ?? "Client ID not found."
//        context["LWA-CLIENTSECRET"] = Environment.get("LWACLIENTSECRET") ?? "Client secret not found"
//        context["SITE-URL"] = Environment.get("SITEURL") ?? "Site url not found"
//        return try req.view().render("home", context)
//    }
    
    router.get {req -> Response in
        logger.info("Main get")
        guard let site = Environment.get("SITEURL") else {throw Abort(.badGateway)}
        return req.redirect(to: "\(site)/lwa/login")
    }

    let alexaController = AlexaController()
    let usersController = UsersController()
    let loginWithAmazonController = LoginWithAmazonController()
    try router.register(collection: alexaController)
    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
}
