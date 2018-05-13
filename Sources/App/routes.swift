import FluentPostgreSQL
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "Hello, world!" example
    router.get("/") { req in
        return "Hello, world!"
    }
    
    let alexaController = AlexaController()
    let usersController = UsersController()
    try router.register(collection: alexaController)
    try router.register(collection: usersController)
}
