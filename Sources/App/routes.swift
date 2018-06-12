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
    let alexaController = AlexaController()
    let testController = TestController()
    //    try router.register(collection: alexaController)
    //    try router.register(collection: usersController)
    try router.register(collection: loginWithAmazonController)
    try router.register(collection: alexaController)
    try router.register(collection: testController)
}

struct ToastyAppRoutes {
    static let site = ENVVariables.siteUrl
    struct lwa {
            static let root = "/lwa"
            static let auth = "\(root)/auth"
            static let login = "\(root)/login"
        }
    struct alexa {
        static let root = "/Alexa"
        static let discovery = "\(root)/Discovery"
    }
    struct test {
        static let root = "/test"
        static let reset = "\(root)/reset"
    }
}
