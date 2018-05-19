import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
//    Swift.print("Starting main router")
    
    router.get {req -> String in
//        let logger = try req.make(Logger.self)
        Swift.print("Main get")
        guard let site = Environment.get("SITEURL") else {throw Abort(.notImplemented)}
//        return req.redirect(to: "\(site)/lwa/login")
        return "Hello from \(site)"
    }
//
//    let alexaController = AlexaController()
//    let usersController = UsersController()
//    let loginWithAmazonController = LoginWithAmazonController()
//    try router.register(collection: alexaController)
//    try router.register(collection: usersController)
//    try router.register(collection: loginWithAmazonController)
}
