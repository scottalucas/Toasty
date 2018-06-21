@testable import App
import Vapor
import XCTest
import FluentPostgreSQL

final class FireplaceOnOffTests: XCTestCase {
    
    var app: Application!
    
    var jsonValidator = Validator.shared
    
    
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
    
    func testDiscoverySuccess () {
        try! fpDiscoverySuccess(accessToken: "test")
    }
    
    func testFpSuccessResponse () {
        try! fpSuccessResponse(action: "TurnOn", impTarget: "https://agent.electricimp.com/7NjKoDqiOxi5")
        try! fpSuccessResponse(action: "TurnOff", impTarget: "https://agent.electricimp.com/7NjKoDqiOxi5")
    }
    
    func testFpFailResponse () {
        print ("\n\n\n\n********************MALFORMED IMP ACTION*****************\n")
        try! fpFailResponse(action: "malformed", impTarget: "https://agent.electricimp.com/7NjKoDqiOxi5", accessToken: "test")
        print ("\n\n\n\n********************MALFORMED IMP URL*****************\n")
        try! fpFailResponse(action: "TurnOff", impTarget: "https://agent.electricimp.com/notfound", accessToken: "test")
        print ("\n\n\n\n********************MALFORMED ACCESS TOKEN*****************\n")
        try! fpFailResponse(action: "TurnOff", impTarget: "https://agent.electricimp.com/7NjKoDqiOxi5", accessToken: "testFail")
    }
    
    func fpDiscoverySuccess (accessToken: String) throws {
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() } //closes the database when out of scope no matter what.
        let myContainer = try! app.client().container
        let myReq = Request.init(using: myContainer)
        let azAcct = try! User.getAmazonAccount(usingToken: accessToken, on: myReq).wait()
        let expectedFps = try! AlexaController.getAssociatedFireplaces(using: azAcct, on: myReq).wait()
        let msgId:String = TestHelpers.randomAlphaNumericString(length: 10)
        let jsonData = String(format: AlexaJson.discoveryReq, msgId, accessToken).data(using: .utf8)! //param: msgId, token
        let res = try app.client().post("http://192.168.1.111:8080/Alexa/Discovery") {newPost in
            newPost.http.body = HTTPBody(data: jsonData)
            newPost.http.headers.add(name: .contentType, value: "application/json")
            }
            .wait()
        let responseJson = (res.http.body).data!
        let responseJsonString = String.init(data: responseJson, encoding: .utf8)
        XCTAssert(res.http.status.code == 200, "Returned HTTP status code \(res.http.status.code), should be 200.")
        XCTAssertTrue(jsonValidator.analyze(responseJsonString!), "Invalid JSON.")
        guard let discoveryResponse:AlexaDiscoveryResponse = try? res.content.syncDecode(AlexaDiscoveryResponse.self) else {
            XCTFail("Could not decode response as AlexaDiscoveryResponse.")
                print("\n\n\(String.init(data: responseJson, encoding: .utf8) ?? "Could not stringify response.")\n\n")
                return
        }
        let header = discoveryResponse.event.header
        let endpoints = discoveryResponse.event.payload.endpoints
        XCTAssert(header.namespace == .discovery, "Header namespace incorrect.")
        XCTAssert(header.name == .discoverResponse, "Header namespace incorrect.")
        XCTAssert(header.payloadVersion == .latest, "Header namespace incorrect.")
        XCTAssert(header.messageId == msgId, "Message ID incorrect.")
        for discoveredFireplace in endpoints {
            let endpointId = discoveredFireplace.endpointId
            let expectedFps = expectedFps.filter { $0.id! == endpointId }
            XCTAssert(expectedFps.count != 0, "No matching fireplaces found.")
            XCTAssert(expectedFps.count == 1, "Multiple fireplaces found.")
            guard let expectedFp = expectedFps.first else { XCTFail("Matching fireplace is nil."); return }
            let associatedAlexaFps = try! expectedFp.alexaFireplaces.query(on: db).all().wait()
            XCTAssert(associatedAlexaFps.count == 1, "Incorrect number of associated Alexa fireplaces.")
            XCTAssert(discoveredFireplace.manufacturerName == FireplaceConstants.manufacturerName, "Mfg name mismatch")
            XCTAssert(discoveredFireplace.description == FireplaceConstants.description, "Description mismatch")
            XCTAssert(discoveredFireplace.displayCategories == FireplaceConstants.displayCategories, "Display category mismatch.")
        }
    }
    
    func fpSuccessResponse(action: String, impTarget: String) throws {
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() }
        let targetFp = try! Fireplace.query(on: db).filter(\.controlUrl == impTarget).first().wait()
        let endpointId = targetFp!.id
        let msgId:String = TestHelpers.randomAlphaNumericString(length: 10)
        let corrToken:String = TestHelpers.randomAlphaNumericString(length: 10)
        let accToken:String = "test"
        let json = String(format: AlexaJson.fpOnOffReq, action, msgId, corrToken, accToken, endpointId!.uuidString)// param: OnOff, messageID, correlationToken, AccessToken, enpoint ID
        let jsonData = json.data(using: .utf8)!
        let res = try app.client().post("http://192.168.1.111:8080/Alexa/PowerController") {newPost in
                newPost.http.body = HTTPBody(data: jsonData)
                newPost.http.headers.add(name: .contentType, value: "application/json")
            }
            .wait()
        print (res.http.status)
        let responseJson = (res.http.body).data!
        let responseJsonString = String.init(data: responseJson, encoding: .utf8)
        XCTAssertTrue(jsonValidator.analyze(responseJsonString!), "JSON did not validate.")
        XCTAssert(res.http.status.code == 200, "Returned HTTP status code other than 200.")
        guard let responseToAlexa:AlexaResponse = try? res.content.syncDecode(AlexaResponse.self) else {
            XCTFail("Could not decode response as AlexaResponse.")
            print(responseJsonString ?? "No JSON to print after decode failure, test \(#function), line \(#line).")
            return
        }
        let powerProp = responseToAlexa.context.properties?.first { $0.namespace == .power}
        let healthProp = responseToAlexa.context.properties?.first { $0.namespace == .health }
        let header = responseToAlexa.event.header
        let endpoint = responseToAlexa.event.endpoint
        let scope = endpoint.scope
        XCTAssertNotNil(powerProp, "Power property not found.")
        XCTAssertNotNil(healthProp, "Health property not found.")
        XCTAssert(powerProp!.name == .power, "Power property name not correct, sending \(powerProp!.name)")
        XCTAssert(healthProp!.name == .connectivity, "Health property name not correct, sending \(healthProp!.name).")
        XCTAssert(powerProp!.value == ((action == "TurnOn") ? "ON" : "OFF"), "Power property value not correct, sending \(powerProp!.value).")
        XCTAssert(healthProp!.value == "OK", "Power property value not correct sending \(healthProp!.value)")
        XCTAssert(header.namespace == .basic, "Header namespace incorrect.")
        XCTAssert(header.name == .response, "Header namespace incorrect.")
        XCTAssert(header.payloadVersion == .latest, "Header namespace incorrect.")
        XCTAssertNotNil(header.correlationToken!, "Correlation token is nil.")
        XCTAssert(header.correlationToken! == corrToken, "Correlation token incorrect.")
        XCTAssert(header.messageId == msgId, "Message ID incorrect.")
        XCTAssertNotNil(scope!, "Scope is not present.")
        XCTAssert(scope!.type == "BearerToken", "Bearer token type incorrect.")
        XCTAssert(scope!.token == accToken, "Access token incorrect.")
        XCTAssert(endpoint.endpointId == endpointId!.uuidString, "Endpoint ID incorrect.")
    }
    
    func fpFailResponse(action: String, impTarget: String, accessToken: String) throws {
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() } //closes the database when out of scope no matter what.
        let targetFp = try! Fireplace.query(on: db).filter(\.controlUrl == impTarget).first().wait()
        let endpointId = targetFp?.id ?? UUID.init()
        let msgId:String = TestHelpers.randomAlphaNumericString(length: 10)
        let corrToken:String = TestHelpers.randomAlphaNumericString(length: 10)
        let accToken:String = accessToken
        let json = String(format: AlexaJson.fpOnOffReq, action, msgId, corrToken, accToken, endpointId.uuidString)// param: OnOff, messageID, correlationToken, AccessToken, enpoint ID
        let jsonData = json.data(using: .utf8)!
        let res = try app.client().post("http://192.168.1.111:8080/Alexa/PowerController") {newPost in
            newPost.http.body = HTTPBody(data: jsonData)
            newPost.http.headers.add(name: .contentType, value: "application/json")
            }
            .wait()
        let responseJson = (res.http.body).data!
        let responseJsonString = String.init(data: responseJson, encoding: .utf8)
        XCTAssert(res.http.status.code == 200, "Returned HTTP status code \(res.http.status.code), should be 200.")
        XCTAssertTrue(jsonValidator.analyze(responseJsonString!), "Invalid JSON.")
        guard let responseToAlexa:AlexaErrorResponse = try? res.content.syncDecode(AlexaErrorResponse.self) else {
            XCTFail("Could not decode response as AlexaErrorResponse.")
            print(responseJsonString ?? "No JSON to print after decode failure, test \(#function), line \(#line).")
            return
        }
        let header = responseToAlexa.event.header
        let endpoint = responseToAlexa.event.endpoint
        let scope = endpoint.scope
        let payload = responseToAlexa.event.payload
        XCTAssertNotNil(scope!, "Scope property not found.")
//        XCTAssert(healthProp!.value == "OK", "Power property value not correct sending \(healthProp!.value)")
        XCTAssert(header.namespace == .basic, "Header namespace incorrect.")
        XCTAssert(header.name == .error, "Header namespace incorrect.")
        XCTAssert(header.payloadVersion == .latest, "Header namespace incorrect.")
        XCTAssertNotNil(header.correlationToken!, "Correlation token is nil.")
        XCTAssert(header.correlationToken! == corrToken, "Correlation token incorrect.")
        XCTAssert(header.messageId == msgId, "Message ID incorrect.")
        XCTAssert(scope!.type == "BearerToken", "Bearer token type incorrect.")
        XCTAssert(scope!.token == accToken, "Access token incorrect.")
        XCTAssert(endpoint.endpointId == endpointId.uuidString, "Endpoint ID incorrect.")
        XCTAssertNotNil(payload.type, "No payload type.")
        XCTAssertNotNil(payload.message, "No error message.")
    }

    static let allTests = [
        ("Test discovery success response", testDiscoverySuccess),
        ("Test fireplace success response", testFpSuccessResponse),
        ("Test fireplace falure response", testFpFailResponse)
        ]
}

struct TestHelpers {
    static func randomAlphaNumericString(length: Int) -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.count)
        var randomString = ""
        
        for _ in 0..<length {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
            let newCharacter = allowedChars[randomIndex]
            randomString += String(newCharacter)
        }
        
        return randomString
    }

}
