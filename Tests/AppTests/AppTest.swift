@testable import App
import Vapor
import XCTest
import FluentPostgreSQL

final class AppTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() {
        
        do {
            var config = Config.default()
            var env = try Environment.detect()
            var services = Services.default()
            
            // this line clears the command-line arguments
            env.commandInput.arguments = []
            
            try App.configure(&config, &env, &services)
            
            app = try Application(
                config: config,
                environment: env,
                services: services
            )
            
            try App.boot(app)
            try app.asyncRun().wait()
            let _ = try app.client().get("http://localhost:8080/test/reset").wait()
        } catch {
            fatalError("Failed to launch Vapor server: \(error.localizedDescription)")
        }
    }
    
    override func tearDown() {
        try? app.runningServer?.close().wait()
    }
    
    func testNothing() throws {
        var fps:[Fireplace] = []
        fps.append(Fireplace(power: .battery, imp: "test url", user: userId, friendly: "test 1"))
        fps.append(Fireplace(power: .line, imp: "test2 url", user: userId, friendly: "test 2"))
        let _ = try app.client().post(
//        let user = User.init(userId: UUID.init()).save(on: database)
        
        print (userId)
        XCTAssert(true)
    }
    
    static let allTests = [
        ("testNothing", testNothing),
        ]
}
