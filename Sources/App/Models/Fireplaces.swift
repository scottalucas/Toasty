import Foundation
import Vapor
import FluentPostgreSQL

final class Fireplace:Codable, Model {
    var id:UUID? //convert to string and use as amazon endpoint id
    var friendlyName:String?
    var powerSource:String?
    var controlUrl:String? //unique to each physical fireplace
    var userId:User.ID?

    func turnOn () {
    //stub
    }
    
    func turnOff () {
    //stub
    }
}

extension Fireplace: PostgreSQLUUIDModel {}
extension Fireplace: Content {}
extension Fireplace: Migration {}
extension Fireplace: Parameter {}
extension Fireplace {
    var user: Parent<Fireplace, User>? {
        return parent(\.userId)
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
