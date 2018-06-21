//
//  FireplaceManagementController.swift
//  Toasty
//
//  Created by Scott Lucas on 5/23/18.
//

//import Foundation
import Vapor
import Fluent
import FluentPostgreSQL

struct FireplaceManagementController {
    
    static func action (_ action: ImpFireplaceAction, executeOn url: String, on req: Request) -> Future<ImpFireplaceAck> {
//        guard let client = try? req.make(Client.self) else { return Future.map(on: req) {alexaResponseStatus.NotAvailable} }
        do {
            guard let postUrl = URL.init(string: url)
                else {
                    throw ImpError(.badUrl, file: #file, function: #function, line: #line)
            }
            return try req.client().post(postUrl) { newPost in
                newPost.http.headers.add(name: .contentType, value: "application/json")
                do {
                    try newPost.content.encode(action)
                } catch {
                    throw AlexaError(.couldNotEncode, file: #file, function: #function, line: #line)
                }
                }.map (to: ImpFireplaceAck.self) { res in
                    do {
                        return try res.content.syncDecode(ImpFireplaceAck.self)
                    } catch {
                        throw AlexaError(.couldNotDecode, file: #file, function: #function, line: #line)
                    }
            }
        } catch {
            if let err = error as? ImpError {
                logger.error("\(err.description)\n\tfile: \(err.file ?? "not provided.")\n\tfunction: \(err.function ?? "not provided.")\n\tline: \(err.line.debugDescription)")
            } else {
                logger.error("Unspecified error in file \(#file), at function \(#function), on line \(String(#line))")
            }
            return Future.map(on: req) {ImpFireplaceAck()}
        }
    }
    
    func discoverFireplaces (for user: User, context req: Request ) {
    //stub
    }

    func addFireplace (to userAccount: User, add fireplace: Fireplace ) {
        //stub
    }

}
