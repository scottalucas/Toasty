import Foundation
import Vapor
import FluentPostgreSQL

final class Fireplace: Codable {
    var id:UUID?
    var friendlyName:String
    var powerSource:PowerSource
    var controlUrl:String //unique to each physical fireplace
    var parentUserId:User.ID

    enum PowerSource: Int, Codable, PostgreSQLEnumType {
        case battery, line
    }
    
    init (power source: PowerSource, imp agentUrl: String, user acctId: UUID, friendly name: String?) {
        powerSource = source
        controlUrl = agentUrl
        parentUserId = acctId
        friendlyName = name ?? "Toasty Fireplace"
    }
}



extension Fireplace: PostgreSQLUUIDModel {}
extension Fireplace: Content {}
extension Fireplace: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            try builder.addReference(from: \.parentUserId, to: \User.id)
        }
    }
}
extension Fireplace: Parameter {}
extension Fireplace {
    var user: Parent<Fireplace, User> {
        return parent(\.parentUserId)
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
