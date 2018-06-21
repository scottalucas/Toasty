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
                    saveResults.append(Fireplace.init(power: fireplace.powerSource, imp: fireplace.controlUrl, user: usrId, friendly: fireplace.friendlyName).save(on: req))
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
        
    }
}
