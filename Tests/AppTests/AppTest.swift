@testable import App
import Vapor
import XCTest
import FluentPostgreSQL

final class FireplaceOnOffTests: XCTestCase {
    
    var app: Application!
    
    var jsonValidator = Validator.shared
    var testUser:User? = nil
    var testAzAcct: AmazonAccount? = nil
    var goodTestFp1: Fireplace? = nil
    var goodTestFp2: Fireplace? = nil
    var badUrltestFp1: Fireplace? = nil
    var goodTestFireplaces: [Fireplace]? = nil
    
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
        testUser = try! User.init().save(on: db).wait()
        let prof = LWACustomerProfileResponse(user_id: testUser!.id!.uuidString, email: "someone@somewhere.com", name: "Test", postal_code: "94024")
        testAzAcct = try! AmazonAccount(with: prof, user: testUser!)!.save(on: db).wait()
        goodTestFp1 = try! Fireplace(power: .battery, imp: "https://agent.electricimp.com/2arZveArVIRJ", user: testUser!.id!, friendly: "test 1").save(on: db).wait()
        goodTestFp2 = try! Fireplace(power: .battery, imp: "https://agent.electricimp.com/7NjKoDqiOxi5", user: testUser!.id!, friendly: "test 1").save(on: db).wait()
        badUrltestFp1 = try! Fireplace(power: .line, imp: "https://httpstat.us/200?sleep=8000", user: testUser!.id!, friendly: "test 2").save(on: db).wait()
        _ = try! AlexaFireplace(childOf: goodTestFp1!, associatedWith: testAzAcct!)!.save(on: db).wait()
        _ = try! AlexaFireplace(childOf: goodTestFp2!, associatedWith: testAzAcct!)!.save(on: db).wait()
        _ = try! AlexaFireplace(childOf: badUrltestFp1!, associatedWith: testAzAcct!)!.save(on: db).wait()
        goodTestFireplaces = [goodTestFp1!, goodTestFp2!]
    }

    override func tearDown() {
        try? app.runningServer?.close().wait()
    }
    
    func testDiscoverySuccess () {
        try! fpDiscoverySuccess(accessToken: "test")
    }
    
    func testStatusReport () {
        for fireplace in goodTestFireplaces! {
            try! statusReportSuccess(accessToken: "test", fireplace: fireplace)
        }
    }
    
    func testFpSuccessResponse () {
        for fireplace in goodTestFireplaces! {
            try! fpSuccessResponse(action: "TurnOn", fireplace: fireplace)
            try! fpSuccessResponse(action: "TurnOff", fireplace: fireplace)
        }

    }
    
    func testFpFailResponse () {
        for fireplace in goodTestFireplaces! {
            try! fpFailResponse(action: "malformed", accessToken: "test", fireplace: fireplace)
            try! fpFailResponse(action: "TurnOff", accessToken: "testFail", fireplace: fireplace)
            
        }
        try! fpFailResponse(action: "TurnOff", accessToken: "test", fireplace: badUrltestFp1!)

    }
    
    func fpDiscoverySuccess (accessToken: String) throws {
        print (String(format: Banners.start, #function))
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() } //closes the database when out of scope no matter what.
        let myContainer = try! app.client().container
        let myReq = Request.init(using: myContainer)
        let azAcct = try! User.getAmazonAccount(usingToken: accessToken, on: myReq).wait()
        let expectedFps = try! AlexaController.getAssociatedFireplaces(using: azAcct, on: myReq).wait()
        let msgId:String = TestHelpers.randomAlphaNumericString(length: 10)
        let jsonData = String(format: AlexaJson.discoveryReq, msgId, accessToken).data(using: .utf8)! //param: msgId, token
        let fpReplyExpectation = XCTestExpectation(description: String(format: Banners.fail, "Did not respond within 8 seconds.", #function, #line))
        try! app.client().post("http://192.168.1.111:8080/Alexa/Discovery") {newPost in
            newPost.http.body = HTTPBody(data: jsonData)
            newPost.http.headers.add(name: .contentType, value: "application/json")
            }.map () { res in
                fpReplyExpectation.fulfill()
                let responseJson = (res.http.body).data!
                let responseJsonString = String.init(data: responseJson, encoding: .utf8)
                XCTAssert(res.http.status.code == 200, String(format: Banners.fail, "Returned HTTP status code \(res.http.status.code), should be 200."))
                XCTAssertTrue(self.jsonValidator.analyze(responseJsonString!), String(format: Banners.fail, "Invalid JSON.", #function, #line))
                guard let discoveryResponse:AlexaDiscoveryResponse = try? res.content.syncDecode(AlexaDiscoveryResponse.self) else {
                    XCTFail(String(format: Banners.fail, "Could not decode response as AlexaDiscoveryResponse.", #function, #line))
                        print("\n\n\(String.init(data: responseJson, encoding: .utf8) ?? "Could not stringify response.")\n\n")
                        return
                }
                let header = discoveryResponse.event.header
                let endpoints = discoveryResponse.event.payload.endpoints
                XCTAssert(header.namespace == .discovery, String(format: Banners.fail, "Header namespace incorrect.", #function, #line))
                XCTAssert(header.name == .discoverResponse, String(format: Banners.fail, "Header namespace incorrect.", #function, #line))
                XCTAssert(header.payloadVersion == .latest, String(format: Banners.fail, "Header namespace incorrect.", #function, #line))
                XCTAssert(header.messageId == msgId, String(format: Banners.fail, "Message ID incorrect.", #function, #line))
                for discoveredFireplace in endpoints {
                    let endpointId = discoveredFireplace.endpointId
                    let expectedFps = expectedFps.filter { $0.id! == endpointId }
                    XCTAssert(expectedFps.count != 0, String(format: Banners.fail, "No matching fireplaces found.", #function, #line))
                    XCTAssert(expectedFps.count == 1, String(format: Banners.fail, "Multiple fireplaces found.", #function, #line))
                    guard let expectedFp = expectedFps.first else { XCTFail(String(format: Banners.fail, "Matching fireplace is nil.", #function, #line)); return }
                    try! expectedFp.alexaFireplaces
                        .query(on: db)
                        .all()
                        .map () { associatedAlexaFps in
                            XCTAssert(associatedAlexaFps.count == 1, String(format: Banners.fail, "Incorrect number of associated Alexa fireplaces.", #function, #line))
                            XCTAssert(discoveredFireplace.manufacturerName == FireplaceConstants.manufacturerName, String(format: Banners.fail, "Mfg name mismatch", #function, #line))
                            XCTAssert(discoveredFireplace.description == FireplaceConstants.description, String(format: Banners.fail, "Description mismatch", #function, #line))
                            XCTAssert(discoveredFireplace.displayCategories == FireplaceConstants.displayCategories, String(format: Banners.fail, "Display category mismatch.", #function, #line))
                        }
                    }
        }
        wait(for: [fpReplyExpectation], timeout: 8.0)
        print (String(format: Banners.finish, #function))
    }
    
    func fpSuccessResponse(action: String, fireplace: Fireplace) throws {
        print (String(format: Banners.start, #function))
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() }
        let endpointId = fireplace.id
        let msgId:String = TestHelpers.randomAlphaNumericString(length: 10)
        let corrToken:String = TestHelpers.randomAlphaNumericString(length: 10)
        let accToken:String = "test"
        let json = String(format: AlexaJson.fpOnOffReq, action, msgId, corrToken, accToken, endpointId!.uuidString)// param: OnOff, messageID, correlationToken, AccessToken, enpoint ID
        let jsonData = json.data(using: .utf8)!
        let fpReplyExpectation = XCTestExpectation(description: String(format: Banners.fail, "Did not respond within 8 seconds.", #function, #line))
        try app.client().post("http://192.168.1.111:8080/Alexa/PowerController") {newPost in
                newPost.http.body = HTTPBody(data: jsonData)
                newPost.http.headers.add(name: .contentType, value: "application/json")
        }.map() { res in
    //        print (res.http.status)
            fpReplyExpectation.fulfill()
            let responseJson = (res.http.body).data!
            let responseJsonString = String.init(data: responseJson, encoding: .utf8)
            XCTAssertTrue(self.jsonValidator.analyze(responseJsonString!), String(format: Banners.fail, "JSON did not validate.", #function, #line))
            XCTAssert(res.http.status.code == 200, String(format: Banners.fail, "Returned HTTP status code other than 200.", #function, #line))
            guard let responseToAlexa:AlexaPowerControllerResponse = try? res.content.syncDecode(AlexaPowerControllerResponse.self) else {
                XCTFail(String(format: Banners.fail, "Could not decode response as AlexaPowerControllerResponse.", #function, #line))
                print(responseJsonString ?? "No JSON to print after decode failure, test \(#function), line \(#line).")
                return
            }
            let powerProp = responseToAlexa.context.properties?.first { $0.namespace == .power}
            let healthProp = responseToAlexa.context.properties?.first { $0.namespace == .health }
            let header = responseToAlexa.event.header
            let endpoint = responseToAlexa.event.endpoint
            let scope = endpoint.scope
            XCTAssertNotNil(powerProp, String(format: Banners.fail, "Power property not found.", #function, #line))
            XCTAssertNotNil(healthProp, String(format: Banners.fail, "Health property not found.", #function, #line))
            XCTAssert(powerProp!.name == .power, String(format: Banners.fail, "Power property name not correct, sending \(powerProp!.name)", #function, #line))
            XCTAssert(healthProp!.name == .connectivity, String(format: Banners.fail, "Health property name not correct, sending \(healthProp!.name).", #function, #line))
            XCTAssert(powerProp!.value == ((action == "TurnOn") ? "ON" : "OFF"), String(format: Banners.fail, "Power property value not correct, sending \(powerProp!.value).", #function, #line))
            XCTAssert(healthProp!.value == "OK", String(format: Banners.fail, "Power property value not correct sending \(healthProp!.value)", #function, #line))
            XCTAssert(header.namespace == .basic, String(format: Banners.fail, "Header namespace incorrect.", #function, #line))
            XCTAssert(header.name == .response, String(format: Banners.fail, "Header namespace incorrect.", #function, #line))
            XCTAssert(header.payloadVersion == .latest, String(format: Banners.fail, "Header namespace incorrect.", #function, #line))
            XCTAssertNotNil(header.correlationToken!, String(format: Banners.fail, "Correlation token is nil.", #function, #line))
            XCTAssert(header.correlationToken! == corrToken, String(format: Banners.fail, "Correlation token incorrect.", #function, #line))
            XCTAssert(header.messageId == msgId, String(format: Banners.fail, "Message ID incorrect.", #function, #line))
            XCTAssertNotNil(scope!, String(format: Banners.fail, "Scope is not present.", #function, #line))
            XCTAssert(scope!.type == "BearerToken", String(format: Banners.fail, "Bearer token type incorrect.", #function, #line))
            XCTAssert(scope!.token == accToken, String(format: Banners.fail, "Access token incorrect.", #function, #line))
            XCTAssert(endpoint.endpointId == endpointId!.uuidString, String(format: Banners.fail, "Endpoint ID incorrect.", #function, #line))
        }
        wait(for: [fpReplyExpectation], timeout: 8.0)
        print (String(format: Banners.finish, #function))
    }
    
    func fpFailResponse(action: String, accessToken: String, fireplace: Fireplace) throws {
        let testUrl = fireplace.controlUrl
        print (String(format: Banners.start, #function))
        print ("""

        Action: \(action)
        Access token: \(accessToken)
        Fireplace: \(fireplace)
        Test URL: \(testUrl)

""")
        let db = try! app.newConnection(to: .psql).wait()
        defer { db.close() } //closes the database when out of scope no matter what.
        let endpointId = fireplace.id!
        let msgId:String = TestHelpers.randomAlphaNumericString(length: 10)
        let corrToken:String = TestHelpers.randomAlphaNumericString(length: 10)
        let accToken:String = accessToken
        let json = String(format: AlexaJson.fpOnOffReq, action, msgId, corrToken, accToken, endpointId.uuidString)// param: OnOff, messageID, correlationToken, AccessToken, enpoint ID
        let jsonData = json.data(using: .utf8)!
        let fpReplyExpectation = XCTestExpectation(description: String(format: Banners.fail, "Did not respond within 8 seconds.", #function, #line))
        try app.client().post("http://192.168.1.111:8080/Alexa/PowerController") {newPost in
            newPost.http.body = HTTPBody(data: jsonData)
            newPost.http.headers.add(name: .contentType, value: "application/json")
            }.map () { res in
                let responseJson = (res.http.body).data!
                let responseJsonString = String.init(data: responseJson, encoding: .utf8)
                XCTAssert(res.http.status.code == 200, String(format: Banners.fail, "Returned HTTP status code \(res.http.status.code), should be 200.", #function, #line))
                        XCTAssertTrue(self.jsonValidator.analyze(responseJsonString!), "Invalid JSON.")
                guard
                    let responseToAlexa = try? res.content.syncDecode(AlexaPowerControllerResponse.self),
                    let properties = responseToAlexa.context.properties
                else {
                    XCTFail(String(format: Banners.fail, "Could not decode response as PowerControllerResponse.", #function, #line))
                    print(responseJsonString ?? "No JSON to print after decode failure, test \(#function), line \(#line).")
                    return
                }
                let header = responseToAlexa.event.header
                let endpoint = responseToAlexa.event.endpoint
                let scope = endpoint.scope
                let payload = responseToAlexa.event.payload

                XCTAssertEqual(properties.count, 1, "Incorrect number of properties.")
                XCTAssertNotNil(scope!, String(format: Banners.fail, "Scope property not found.", #function, #line))
                XCTAssert(properties[0].value == "UNREACHABLE", "Power property value not correct sending \(properties[0].value)")
                XCTAssert(header.namespace == .basic, String(format: Banners.fail, "Header namespace incorrect.", #function, #line))
                XCTAssert(header.name == .response, String(format: Banners.fail, "Header name incorrect.", #function, #line))
                XCTAssert(header.payloadVersion == .latest, String(format: Banners.fail, "Payload version incorrect.", #function, #line))
                XCTAssert(header.correlationToken! == corrToken, String(format: Banners.fail, "Correlation token incorrect.", #function, #line))
                XCTAssert(header.messageId == msgId, String(format: Banners.fail, "Message ID incorrect.", #function, #line))
                XCTAssert(scope!.type == "BearerToken", String(format: Banners.fail, "Bearer token type incorrect.", #function, #line))
                XCTAssert(endpoint.endpointId == endpointId.uuidString, String(format: Banners.fail, "Endpoint ID incorrect.", #function, #line))
                XCTAssertNil(payload.type, String(format: Banners.fail, "No payload type.", #function, #line))
                fpReplyExpectation.fulfill()
}
        wait(for: [fpReplyExpectation], timeout: 8.0)
        print (String(format: Banners.finish, #function))
    }
    
    func statusReportSuccess(accessToken: String, fireplace: Fireplace) throws {
        print (String(format: Banners.start, #function))
        let json = String(format: AlexaJson.stateReportReq, fireplace.id!.uuidString, accessToken)
        let jsonData = json.data(using: .utf8)!
        let fpReplyExpectation = XCTestExpectation(description: String(format: Banners.fail, "Did not respond within 8 seconds.", #function, #line))
        try! app.client().post("http://192.168.1.111:8080/Alexa/ReportState") {newPost in
            newPost.http.body = HTTPBody(data: jsonData)
            newPost.http.headers.add(name: .contentType, value: "application/json")
            }.map () {res in
                fpReplyExpectation.fulfill()
                let responseJson = (res.http.body).data!
                let responseJsonString = String.init(data: responseJson, encoding: .utf8)
                XCTAssert(res.http.status.code == 200, String(format: Banners.fail, "Returned HTTP status code \(res.http.status.code), should be 200.", #function, #line))
                XCTAssertTrue(self.jsonValidator.analyze(responseJsonString!), String(format: Banners.fail, "Invalid JSON.", #function, #line))
        }
        wait(for: [fpReplyExpectation], timeout: 8.0)
        print (String(format: Banners.finish, #function))
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
