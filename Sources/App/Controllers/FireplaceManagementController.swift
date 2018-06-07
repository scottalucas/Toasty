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
    
    static func action (_ action: ImpFireplaceDirective, executeOn url: String, on req: Request) -> Future<ImpStatus> {
        guard let client = try? req.make(Client.self) else { return Future.map(on: req) {ImpStatus.NotAvailable} }
        var request:HTTPRequest = HTTPRequest(method: .POST, url: url)
        switch action {
        case .TurnOn:
            request.body = HTTPBody(data: action.json)
            break
        case .TurnOff:
            request.body = HTTPBody(data: action.json)
            break
        }
        let impRequest = Request(http: request, using: req)

        return client.send(impRequest)
            .flatMap (to: ImpStatus.self) { response in
                do {
                    return try response.content.decode(ImpStatus.self)
                } catch {
                    return Future.map(on: req) {ImpStatus.NotAvailable}
                }
        }
    }
    
    func discoverFireplaces (for user: User, context req: Request ) {
    //stub
    }

    func addFireplace (to userAccount: User, add fireplace: Fireplace ) {
        //stub
    }

}
