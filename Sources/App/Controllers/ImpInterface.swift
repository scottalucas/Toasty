//
//  FireplaceManagementController.swift
//  Toasty
//  These methods are used during interactions
//  with the Imp Agent.
//
//  Created by Scott Lucas on 5/23/18.
//

//import Foundation
import Vapor
import Fluent
import FluentPostgreSQL

struct FireplaceManagementController: RouteCollection {
    func boot(router: Router) throws {
        
        let fireplaceRoutes = router.grouped(ToastyServerRoutes.Fireplace.root, ToastyServerRoutes.Fireplace.Update.root)
        
        func updateHandler (_ req: Request) throws -> Future<HTTPStatus> {
            let logger = try req.sharedContainer.make(Logger.self)
            logger.debug ("Hit Imp controller.")
            guard var updatingFireplace = try? req.content.syncDecode(Fireplace.self) else {
                logger.error("Failed to decode inbound request: \(req.http.body.debugDescription)")
                return Future.map(on: req) { HTTPStatus(statusCode: 404, reasonPhrase: "Could not decode request.")}
            }
		
		return Fireplace.query(on: req)
			.filter( \.deviceid == updatingFireplace.deviceid )
			.first()
			.flatMap (to: Fireplace.self) { optFireplace in
				updatingFireplace.lastStatusUpdate = Date()
//				updatingFireplace.parentUserId = optFireplace?.parentUserId ?? User.defaultUserId
				return updatingFireplace.create(orUpdate: true, on: req)
			}.transform(to: HTTPStatus(statusCode: 200, reasonPhrase: "Success!"))
			.catchFlatMap () { error in
				logger.error("Could not decode fireplace update message, error: \(error.localizedDescription).")
                    return Future.map(on: req) { HTTPStatus(statusCode: 404, reasonPhrase: "Could not decode fireplace update message, error: \(error.localizedDescription).") }
            }
        }
	
	func timezoneUpdateHandler (_ req: Request) throws -> Future<HTTPStatus> {
		let logger = try req.sharedContainer.make(Logger.self)
		logger.debug ("Hit timezone update for fireplace.")
		guard
			let fpId = try? req.parameters.next(String.self),
			let tzHours = try? req.parameters.next(Double.self)
			else { throw Abort(.badRequest) }
		return Fireplace
			.find(fpId, on: req)
			.flatMap(to: HTTPStatus.self) { optFp in
				guard let fp = optFp else {return req.future(HTTPStatus.notFound)}
				var updatedFp = fp
				updatedFp.timezone = TimeZone.init(secondsFromGMT: Int(tzHours * 3600.0))
				return updatedFp
					.save(on: req)
					.transform(to: HTTPStatus.ok)
		}
	}
	
	func weatherUrlupdateHandler (_ req: Request) throws -> Future<HTTPStatus> {
		let logger = try req.sharedContainer.make(Logger.self)
		logger.debug ("Hit weather url update for fireplace.")
		guard
			let fp = try? req.parameters.next(String.self),
			let weatherUrl = try? req.parameters.next(String.self),
			let weatherData = Data(base64Encoded: weatherUrl)
			else { throw Abort(.badRequest) }
		return Fireplace
			.find(fp, on: req)
			.flatMap(to: HTTPStatus.self) { optFp in
				guard let fp = optFp,
					let decodedUrl = String(data: weatherData, encoding: .utf8)
					else { throw Abort(.notFound) }
				var updatedFp = fp
				updatedFp.weatherUrl = decodedUrl
				return updatedFp
					.save(on: req)
					.transform(to: HTTPStatus.ok)
		}
	}

	fireplaceRoutes.post(use: updateHandler)
	fireplaceRoutes.get(ToastyServerRoutes.Fireplace.Update.timezone, String.parameter, Double.parameter, use: timezoneUpdateHandler)
	fireplaceRoutes.get(ToastyServerRoutes.Fireplace.Update.weatherUrl, String.parameter, String.parameter, use: weatherUrlupdateHandler)
    }
	static func action (_ action: ImpFireplaceAction, forFireplace fp: Fireplace, on req: Request) throws -> Future<Result<ImpFireplaceStatus, ImpError>> {
		let logger = try? req.make(Logger.self)
		var fireplace = fp
		var finalStatus: ImpFireplaceStatus = ImpFireplaceStatus()
		let sessionConfig = URLSessionConfiguration.default
		sessionConfig.timeoutIntervalForRequest = 7.0
		sessionConfig.timeoutIntervalForResource = 7.0
		let shortSession = URLSession(configuration: sessionConfig)
		let client = FoundationClient.init(shortSession, on: req)
		guard let postUrl = URL.init(string: fireplace.controlUrl) else { return req.future(.failure(ImpError(.badUrl, file: #file, function: #function, line: #line))) }
		return client.post(postUrl) { newPost in
			newPost.http.headers.add(name: .contentType, value: "application/json")
			try newPost.content.encode(action)
			}.flatMap(to: ImpFireplaceStatus.self) { res in
				let status = try res.content.decode(ImpFireplaceStatus.self)
				return status
			}.flatMap (to: Fireplace.self) { status in
				finalStatus = status
				fireplace.status = status.value == .ON ? .on : .off
				fireplace.lastStatusUpdate = Date()
				return fireplace.save(on: req)
			}.map(to: Result<ImpFireplaceStatus, ImpError>.self) { fireplace in
				finalStatus.uncertaintyInMilliseconds = fireplace.uncertainty()
				return .success(finalStatus)
			}.catchMap {error in
				logger?.error(error.localizedDescription)
				return .failure(ImpError(.couldNotDecodeImpResponse, file: #file, function: #function, line: #line))
		}
	}
}
