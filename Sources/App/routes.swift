import FluentPostgreSQL
import Vapor
import Fluent
/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get {req -> Response in
        let logger = try req.make(Logger.self)
        logger.debug("In login")
//        var context = [String: String]()
//        context["MSG"] = "\(logMsg)"
        guard
            let site = Environment.get("SITEURL"),
            let authStartPage = "\(site)/lwa/login".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        else {throw Abort(.notImplemented)}
        logger.debug("In login, redirect is: \(site)")
        return req.redirect(to: authStartPage)
//        return try req.view().render("testFeedback", context)
        
    }
    //
    //    let alexaController = AlexaController()
    //    let usersController = UsersController()
    let loginWithAmazonController = LoginWithAmazonController()
    //    try router.register(collection: alexaController)
    //    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
}

