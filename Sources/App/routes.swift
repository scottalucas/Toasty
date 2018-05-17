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
    
    router.get("LwaResponse") { req -> String in
        debugPrint("Hit LwaResponse leaf.")
        debugPrint("Headers: \(req.http.headers.debugDescription)")
        debugPrint("Method: \(req.http.method)")
        debugPrint("URL: \(req.http.urlString)")
        debugPrint("Body: \(req.http.body.debugDescription)")

//        logger.info("Access response key: \(accessValue.access_token.debugDescription)")
//        logger.info("Access response expires: \(accessValue.expires_in.debugDescription)")
//        logger.info("Access response refresh token: \(accessValue.refresh_token.debugDescription)")
//        logger.info("Access response token type: \(accessValue.token_type ?? "Token not found")")
        return "Hit LwaResponse leaf, Headers: \(req.http.headers.debugDescription)\rMethod: \(req.http.method)\rURL: \(req.http.urlString)\rURL: \(req.http.urlString)\rBody: \(req.http.body.debugDescription)"
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
