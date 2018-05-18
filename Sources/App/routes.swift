import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    let logger = PrintLogger()
    logger.info("Starting main router")
    
    router.get {req -> Response in
        let logger = PrintLogger()
        logger.info("Main get")
        guard let site = Environment.get("SITEURL") else {throw Abort(.notImplemented)}
        return req.redirect(to: "\(site)/lwa/login")
    }

    let alexaController = AlexaController()
    let usersController = UsersController()
    let loginWithAmazonController = LoginWithAmazonController()
    try router.register(collection: alexaController)
    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
}
