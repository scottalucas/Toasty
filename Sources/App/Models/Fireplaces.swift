import Foundation
import Vapor
import FluentPostgreSQL

final class Fireplace: Codable {
    var id:Int?
    var friendlyName:String
    var powerSource:String
    var controlUrl:String //unique to each physical fireplace
    var userId:User.ID
    
    init (power source: String?, imp agentUrl: String, user acctId: Int, friendly name: String?) {
        powerSource = source ?? "Unknown"
        controlUrl = agentUrl
        userId = acctId
        friendlyName = name ?? "Toasty Fireplace"
    }
}

enum PowerSource: Int, Codable {
    case battery, line
}

extension Fireplace: PostgreSQLModel {}
extension Fireplace: Content {}
extension Fireplace: Migration {
    //        static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
    //            return Database.create(self, on: connection) { builder in
    //                try addProperties(to: builder)
    //                try builder.addReference(from: \.userId, to: \User.id)
    //            }
    //        }
}
extension Fireplace: Parameter {}
extension Fireplace {
    var user: Parent<Fireplace, User> {
        return parent(\.userId)
    }
    var alexaFireplaces: Children<Fireplace, AlexaFireplace> {
        return children(\.parentFireplaceId)
    }
}

struct CodableFireplace:Content { //structure to decode the fireplaces passed from the app
    var fireplaces:[fireplace]
    struct fireplace:Codable {
        var friendlyName:String
        var powerSource:String
        var controlUrl:String
    }
}

struct CodableFireplaces:Content {
    var fireplaces:[CodableFireplace]
}
