import Foundation
import Vapor
import FluentPostgreSQL

final class Fireplace: Codable {
    var id:UUID?
    var friendlyName:String
    var powerSource:PowerStatus
    var controlUrl:String //unique to each physical fireplace
    var status:FireLevel? //flame is on or off
    var lastStatusUpdate: Date?
    var parentUserId:User.ID?

    enum PowerStatus: Int, Codable, PostgreSQLEnumType {
        case line = -1, low, ok
    }
    
    enum FireLevel: Int, Codable {
        case unknown = -1, off, on
        
        func alexaValue () -> String? {
            switch self {
            case .off:
                return "OFF"
            case .on:
                return "ON"
            default:
                return nil
            }
        }
    }
    
    init (power source: PowerStatus, imp agentUrl: String, user acctId: UUID, friendly name: String?) {
        powerSource = source
        controlUrl = agentUrl
        parentUserId = acctId
        friendlyName = name ?? "Toasty Fireplace"
        status = nil
        lastStatusUpdate = nil
    }
    
    init (fireplaceStatus: CodableFireplace) {
        powerSource = fireplaceStatus.power
        controlUrl = fireplaceStatus.url
        friendlyName = fireplaceStatus.name
        status = fireplaceStatus.level
        lastStatusUpdate = Date()
    }
    
    func uncertainty () -> Int? {
        guard let lastUpdate = lastStatusUpdate else {return nil}
        let milliSecondsElapsed:Int = Int(lastUpdate.timeIntervalSinceNow * 1000)
        return abs(milliSecondsElapsed)
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
    var user: Parent<Fireplace, User>? {
        return parent(\.parentUserId)
    }
    var alexaFireplaces: Children<Fireplace, AlexaFireplace> {
        return children(\.parentFireplaceId)
    }
}



