//
//  FireplaceManagementController.swift
//  Toasty
//  These methods are used during interactions
//  with the Imp Agent.
//
//  Created by Scott Lucas on 5/23/18.
//

import Foundation
import Vapor
import Fluent
import FluentPostgreSQL

struct FireplaceManagementController: RouteCollection {
    func boot(router: Router) throws {
        
        let fireplaceRoutes = router.grouped(ToastyServerRoutes.Fireplace.root, ToastyServerRoutes.Fireplace.Update.root)
        
        func updateHandler (_ req: Request) throws -> Future<Response> {
            let logger = try req.sharedContainer.make(Logger.self)
            logger.debug ("Hit Imp controller.")
            let response = Response.init(using: req)
            guard var updatingFireplace = try? req.content.syncDecode(Fireplace.self) else {
                let err = "Failed to decode inbound request: \(req.http.body.debugDescription)"
                logger.error(err)
                response.http.status = .badRequest
                response.http.body = HTTPBody.init(string: err)
                return req.future(response)
            }
            updatingFireplace.lastStatusUpdate = Date()
            return updatingFireplace.create(orUpdate: true, on: req)
                .map(to: Response.self) { fp in
                    response.http.status = .accepted
                    response.http.body = HTTPBody.init(string: "Success!")
                    return response
                }
                .catchMap () { error in
                    let err = "Could not decode fireplace update message, error: \(error.localizedDescription)."
                    logger.error(err)
                    response.http.status = .internalServerError
                    response.http.body = HTTPBody.init(string: err)
                    return response
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
        
        func publicKeyHandler (_ req: Request) throws -> String {
            struct HandlerResponse: Codable {
                var keyId: String = ENV.keyVersion
                var key: String = ENV.publicKey
                static var current: String {
                    let encoder = JSONEncoder()
                    let d = try? encoder.encode(HandlerResponse())
                    return String(data: d ?? "".data(using: .utf8)!, encoding: .utf8) ?? ""
                }
            }
            return HandlerResponse.current
        }
        
        func updateBatteryHandler (_ req: Request) throws -> Future<String> {
            return try req.parameters.next(Fireplace.self)
                .flatMap(to: Fireplace.self) { fp in
                    var updatedFp = fp
                    guard let newBattLevel = try? req.parameters.next(Float.self) else {throw Abort(.notFound)}
                    updatedFp.batteryLevel = newBattLevel
                    return updatedFp.save(on: req)
                }
                .flatMap (to: BatteryLog.self) { fp in
                    guard let id = fp.id, let newBattLevel = fp.batteryLevel else {return Future.map(on: req) {return BatteryLog(id: nil, fireplaceId: "nil", timestamp: Date(), batteryLevel: 0.0)}}
                    let logEntry = BatteryLog(id: nil, fireplaceId: id, timestamp: Date(), batteryLevel: newBattLevel)
                    return logEntry.save(on: req)
                }
                .map (to: String.self) { logEntry in
                    if logEntry.id == nil {return "Fail"}
                    else {return "Success, id \(logEntry.id!), batt level \(logEntry.batteryLevel)"}
            }
        }
        
        fireplaceRoutes.put(use: updateHandler)
        fireplaceRoutes.get(ToastyServerRoutes.Fireplace.Update.timezone, String.parameter, Double.parameter, use: timezoneUpdateHandler)
        //	fireplaceRoutes.get(ToastyServerRoutes.Fireplace.Update.weatherUrl, String.parameter, String.parameter, use: weatherUrlupdateHandler)
        fireplaceRoutes.get(ToastyServerRoutes.Fireplace.Update.rotateKey, use: publicKeyHandler)
        fireplaceRoutes.get(ToastyServerRoutes.Fireplace.Update.updateBatteryLevel, Fireplace.parameter, Float.parameter, use: updateBatteryHandler)
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
        guard let token = TokenManager.basicToken else { return req.future(.failure(ImpError(.couldNotCreateToken, file: #file, function: #function, line: #line))) }
        guard let postUrl = URL.init(string: "\(fireplace.controlUrl)/directive") else { return req.future(.failure(ImpError(.badUrl, file: #file, function: #function, line: #line))) }
        return client.post(postUrl) { newPost in
            newPost.http.headers.add(name: .contentType, value: "application/json")
            newPost.http.headers.add(name: .authorization, value: "Bearer \(token)")
            try newPost.content.encode(action)
            }.flatMap(to: ImpFireplaceStatus.self) { res in
                let status = try res.content.decode(ImpFireplaceStatus.self)
                return status
            }.flatMap (to: Fireplace.self) { status in
                finalStatus = status
                switch status.ack {
                case .acceptedOff:
                    fireplace.status = .off
                case .acceptedOn:
                    fireplace.status = .on
                case .notAvailable, .rejected, .updating:
                    fireplace.status = .unknown
                @unknown default:
                    fireplace.status = .unknown
                }
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
