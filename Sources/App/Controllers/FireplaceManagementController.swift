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
    
    static func action (_ action: ImpFireplaceAction, executeOn fireplace: Fireplace, on req: Request) throws -> Future<ImpFireplaceStatus> {
        guard let postUrl = URL.init(string: fireplace.controlUrl) else { throw ImpError(.badUrl, file: #file, function: #function, line: #line) }
        var finalStatus:ImpFireplaceStatus = ImpFireplaceStatus()
        return try req.client().post(postUrl) { newPost in
            newPost.http.headers.add(name: .contentType, value: "application/json")
            try newPost.content.encode(action)
            }.flatMap(to: ImpFireplaceStatus.self) { res in
                guard let status = try? res.content.decode(ImpFireplaceStatus.self) else {
                    throw ImpError(.couldNotDecodeImpResponse, file: #file, function: #function, line: #line) }
                return status
            }.flatMap (to: Fireplace.self) { status in
                finalStatus = status
                fireplace.status = status.value?.rawValue
                fireplace.lastStatusUpdate = Date()
                return fireplace.save(on: req)
            }.map(to: ImpFireplaceStatus.self) { fireplace in
                finalStatus.uncertaintyInMilliseconds = fireplace.uncertainty()
                return finalStatus
            }.catchFlatMap {error in
                throw error
            }
    }
    
    func discoverFireplaces (for user: User, context req: Request ) {
    //stub
    }

    func addFireplace (to userAccount: User, add fireplace: Fireplace ) {
        //stub
    }

}
