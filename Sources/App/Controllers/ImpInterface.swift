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
        
        let fireplaceRoutes = router.grouped(ToastyServerRoutes.Fireplace.root)
        
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
	
        fireplaceRoutes.post(ToastyServerRoutes.Fireplace.update, use: updateHandler)
    }
    static func action (_ action: ImpFireplaceAction, executeOn fp: Fireplace, on req: Request) throws -> Future<ImpFireplaceStatus> {
        var fireplace = fp
//        let logger = try req.make(Logger.self)
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 7.0
        sessionConfig.timeoutIntervalForResource = 7.0
        let shortSession = URLSession(configuration: sessionConfig)
        let client = FoundationClient.init(shortSession, on: req)
        guard let postUrl = URL.init(string: fireplace.controlUrl) else { throw ImpError(.badUrl, file: #file, function: #function, line: #line) }
        var finalStatus:ImpFireplaceStatus = ImpFireplaceStatus()
        return client.post(postUrl) { newPost in
            newPost.http.headers.add(name: .contentType, value: "application/json")
            try newPost.content.encode(action)
            }.flatMap(to: ImpFireplaceStatus.self) { res in
                guard let status = try? res.content.decode(ImpFireplaceStatus.self) else {
                    throw ImpError(.couldNotDecodeImpResponse, file: #file, function: #function, line: #line) }
                return status
            }.flatMap (to: Fireplace.self) { status in
                finalStatus = status
                fireplace.status = status.value == .ON ? .on : .off
                fireplace.lastStatusUpdate = Date()
                return fireplace.save(on: req)
            }.map(to: ImpFireplaceStatus.self) { fireplace in
                finalStatus.uncertaintyInMilliseconds = fireplace.uncertainty()
                return finalStatus
            }.catchFlatMap {error in
                throw error
            }
    }
}
