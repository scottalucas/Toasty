import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    let logger = PrintLogger()
    router.get { req -> Future<View> in
        var context = [String: String]()
        context["LWA-CLIENTID"] = Environment.get("LWACLIENTID") ?? "Client ID not found."
        context["LWA-CLIENTSECRET"] = Environment.get("LWACLIENTSECRET") ?? "Client secret not found"
        context["SITE-URL"] = Environment.get("SITEURL") ?? "Site url not found"
        return try req.view().render("home", context)
    }
    
    router.get("LwaResponse", AccessResponse.parameter) { req -> String in
        let accessValue:AccessResponse = try req.parameters.next()
        let retVal = req.http.body.debugDescription
        logger.info("Hit LwaResponse leaf.")
        logger.info("Headers: \(req.http.headers.debugDescription)")
        logger.info("Method: \(req.http.method)")
        logger.info("URL: \(req.http.urlString)")
        logger.info("Access response key: \(accessValue.access_token.debugDescription)")
        logger.info("Access response expires: \(accessValue.expires_in.debugDescription)")
        logger.info("Access response refresh token: \(accessValue.refresh_token.debugDescription)")
        logger.info("Access response token type: \(accessValue.token_type)")

        return retVal
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
