import FluentPostgreSQL
import Vapor
import Fluent
/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get {req -> Response in
        let logger = try req.make(Logger.self)
        logger.debug("In login")
        guard
            let site = Environment.get("SITEURL")
            else {throw Abort(.notImplemented, reason: "Server Error: Main site URL not defined")}
        return req.redirect(to: "\(site)\(ToastyAppRoutes.lwa.login)")   
    }
    let loginWithAmazonController = LoginWithAmazonController()
    //    try router.register(collection: alexaController)
    //    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
}

struct ToastyAppRoutes {
    struct lwa {
        static let lwaRoot = "lwa"
        static let auth = "/\(lwaRoot)/auth"
        static let login = "/\(lwaRoot)/login"
    }
}
