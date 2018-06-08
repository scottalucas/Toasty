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
//        guard let client = try? req.make(Client.self) else { return Future.map(on: req) {ImpStatus.NotAvailable} }
        do {
            return try req.client().post(URL.init(string: url)!) { newPost in
                newPost.http.headers.add(name: .contentType, value: "application/json")
                try newPost.content.encode(action)
                }.map (to: ImpFireplaceAck.self) { res in
                    return try res.content.syncDecode(ImpFireplaceAck.self)
                }
        } catch {
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
