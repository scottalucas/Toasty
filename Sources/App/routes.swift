import FluentPostgreSQL
import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    Swift.print("Starting main router")
    
    router.get {req -> Future<View> in
        let logMsg = "Tell me something."
        let logger = try req.make(PrintLogger.self)
        logger.info(logMsg)
        Swift.print(logMsg)
        var context = [String: String]()
        context["MSG"] = "\(logMsg)"
//        guard let site = Environment.get("SITEURL") else {throw Abort(.notImplemented)}
        //        return req.redirect(to: "\(site)/lwa/login")
        return try req.view().render("testFeedback", context)
        
    }
    //
    //    let alexaController = AlexaController()
    //    let usersController = UsersController()
    let loginWithAmazonController = LoginWithAmazonController()
    //    try router.register(collection: alexaController)
    //    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
}

