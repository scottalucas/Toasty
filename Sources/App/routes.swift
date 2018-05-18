import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    let logger = PrintLogger()
    logger.info("Starting main router")
    router.get { req -> Future<View> in
        var context = [String: String]()
        context["LWA-CLIENTID"] = Environment.get("LWACLIENTID") ?? "Client ID not found."
        context["LWA-CLIENTSECRET"] = Environment.get("LWACLIENTSECRET") ?? "Client secret not found"
        context["SITE-URL"] = Environment.get("SITEURL") ?? "Site url not found"
        return try req.view().render("home", context)
    }
    
    router.get("LwaResponse") { req -> Future<String> in
        return try req.content.decode(LWAAccessAuth.self)
            .map(to: String.self) {codeObj in
                logger.info("Hit LwaResponse leaf.")
                logger.info("Headers: \(req.http.headers.debugDescription)")
                logger.info("Method: \(req.http.method)")
                logger.info("URL: \(req.http.urlString)")
                logger.info("Body: \(req.http.body.debugDescription)")
                return "Hit LwaResponse leaf, Headers: \(req.http.headers.debugDescription)\nMethod: \(req.http.method)\nURL: \(req.http.urlString)\nURL: \(req.http.urlString)\nBody: \(req.http.body.debugDescription)\nCode: \(codeObj.code)\n"
        }
    }
    
    router.post("PostTest") { req -> String in
        let retText = "post test route"
        logger.info("Hit post test route.")
        logger.info("Headers: \(req.http.headers.debugDescription)")
        logger.info("Method: \(req.http.method)")
        logger.info("URL: \(req.http.urlString)")
        return retText
    }
    
    let alexaController = AlexaController()
    let usersController = UsersController()
    let loginWithAmazonController = LoginWithAmazonController()
    try router.register(collection: alexaController)
    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
}
