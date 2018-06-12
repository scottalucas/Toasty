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
            let _ = try app.client().get("http://192.168.1.111:8080/test/reset").wait()
        } catch {
            fatalError("Failed to launch Vapor server: \(error.localizedDescription)")
        }
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() }
        let user = try! User.init().save(on: db).wait()
        let prof = LWACustomerProfileResponse(user_id: user.id!.uuidString, email: "someone@somewhere.com", name: "Test", postal_code: "94024")
        let azAcct = try! AmazonAccount(with: prof, user: user)!.save(on: db).wait()
        let fp1 = try! Fireplace(power: .battery, imp: "https://agent.electricimp.com/7NjKoDqiOxi5", user: user.id!, friendly: "test 1").save(on: db).wait()
        let fp2 = try! Fireplace(power: .line, imp: "test2 url", user: user.id!, friendly: "test 2").save(on: db).wait()
        _ = try! AlexaFireplace(childOf: fp1, associatedWith: azAcct)!.save(on: db).wait()
        _ = try! AlexaFireplace(childOf: fp2, associatedWith: azAcct)!.save(on: db).wait()
    }

    override func tearDown() {
        try? app.runningServer?.close().wait()
    }
    
    func testNothing() throws {
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() }
        let targetFp = try! Fireplace.query(on: db).filter(\.controlUrl == "https://agent.electricimp.com/7NjKoDqiOxi5").first().wait()
        let targetId = targetFp!.id
        let json = String(format: alexaJson.fpOnReq, targetId!.uuidString)
//        print (json)
        let jsonData = json.data(using: .utf8)!
        let res = try app.client().post("http://192.168.1.111:8080/Alexa/PowerController") {newPost in
                newPost.http.body = HTTPBody(data: jsonData)
                newPost.http.headers.add(name: .contentType, value: "application/json")
            }
            .wait()
        print (res.http.status)
        print (res.http.body)
        XCTAssert(res.http.status.code == 200)
    }
    
    static let allTests = [
        ("testNothing", testNothing),
        ]
}
