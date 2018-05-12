import Foundation
import Vapor
import FluentSQLite

final class Fireplace:Codable {
    var id:UUID?
    var controlURL:URL!
    var toastyUserID:UUID
    var alexaEndpointId:String?

    init () {
        toastyUserID = UUID.init()
    }
    
    func turnOn () {
    //stub
    }
    
    func turnOff () {
    //stub
    }
}

extension Fireplace: SQLiteUUIDModel {}
extension Fireplace: Content {}
extension Fireplace: Migration {}
extension Fireplace: Parameter {}
extension Fireplace {
    var user: Parent<Fireplace, User> {
        return parent(\.toastyUserID)
    }
}
