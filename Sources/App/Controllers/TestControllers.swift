//
//  TestControllers.swift
//  Toasty
//
//  Created by Scott Lucas on 6/7/18.
//
import Foundation
import Vapor
import Fluent
import FluentPostgreSQL

struct TestController: RouteCollection {
	func boot(router: Router) throws {
		let testRoutes = router.grouped(ToastyAppRoutes.test.root)
		
		func helloHandler (_ req: Request) -> String {
			return "Hello! You got Test controller!"
		}
		
		func resetHandler(req: Request) throws -> Future<Response> {
			return AlexaFireplace.query(on: req).delete()
				.map() {
					return AmazonAccount.query(on: req).delete()
				}.map() { _ in
					return Fireplace.query(on: req).delete()
				}.map() { _ in
					return User.query(on: req).delete()
				}.map() { _ in
					return Response(http: HTTPResponse(status: .notFound), using: req)
			}
		}
		
		func sendAPNS(req: Request) throws -> Future<Response> {
			let l = try req.make(Logger.self)
//			let jsonAPNSPayloadString = #"""
//			{\"aps\":{\"alert\":\"Hello from Toasty\"}}
//"""#
			let apnsURL = "https://api.development.push.apple.com/3/device/"
			let token = "3dba60b2d75af056c155e5fcd36bd657c08753c66f95f8cde8e91b89331468bd"
			let pw = ENV.PRIVATE_KEY_PASSWORD
			let path = ENV.PRIVATE_KEY_PATH
			let bundleId = ENV.APP_ID
			let shell = try req.make(Shell.self)
			let arguments = ["-d", "@apns.json", "-H", "apns-topic:\(bundleId)", "-H", "apns-expiration: 1", "-H", "apns-priority: 10", "— http2-prior-knowledge", "— cert", "\(path):\(pw)", apnsURL + token]
			l.debug("Shell args: \(arguments.debugDescription)")
			return try shell.execute(commandName: "curl", arguments: arguments)
				.map(to: Response.self) { data in
					let curlResponse = String(data: data, encoding: .utf8)
					l.debug(curlResponse ?? "No curl response.")
					var response = HTTPResponse(status: .ok)
					response.body = HTTPBody(string: "Curl response: \(curlResponse ?? "none.")")
					l.debug("Returning response.")
					return Response(http: response, using: req)
			}
		}
		
		func setUpTestDatabaseRecords(req: Request) throws -> Future<Response> {
			guard
				let fireplaces = try? req.content.syncDecode([Fireplace].self),
				fireplaces.count > 0
				else {
					let msg = "No fireplaces found or malformed JSON in request, please discover fireplaces first."
					let res = req.makeResponse()
					try res.content.encode(msg, as: .plainText)
					return Future.map(on: req) {res}
			}
			return User(name: "Placeholder", username: "Placeholder")
				.save(on: req)
				.flatMap(to: [Fireplace].self) { usr in
					guard let usrId = usr.id else { throw AlexaError(.placeholderAccountNotFound, file: #file, function: #function, line: #line)}
					var saveResults: [Future<Fireplace>] = []
					for fireplace in fireplaces {
						saveResults.append(Fireplace.init(power: fireplace.powerStatus, imp: fireplace.controlUrl, user: usrId, friendly: fireplace.friendlyName).save(on: req))
					}
					return saveResults.flatten(on: req)
				}.map (to: Response.self) { fps in
					let res = req.makeResponse()
					try res.content.encode(fps, as: .json)
					return res
			}
		}
		
		testRoutes.get(use: helloHandler)
		testRoutes.get("reset", use: resetHandler)
		testRoutes.post("setUpUser", use: setUpTestDatabaseRecords)
		testRoutes.get("apns", use: sendAPNS)
		
	}
}
