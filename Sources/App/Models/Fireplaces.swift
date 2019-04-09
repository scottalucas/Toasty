import Foundation
import Vapor
import FluentPostgreSQL

struct Fireplace: Codable {
    var id:UUID?
    var friendlyName:String
    var powerStatus:PowerStatus
    var controlUrl:String //unique to each physical fireplace
    var status:FireLevel //flame is on or off
    var lastStatusUpdate: Date?
    var parentUserId:User.ID?

//    enum PowerStatus: Int, Codable, PostgreSQLEnumType {
	enum PowerStatus: Int, Codable {
        case line = -1, low, ok
    }
    
//    enum FireLevel: Int, Codable, PostgreSQLEnumType {
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
    
    enum CodingKeys: String, CodingKey {
        case id, friendlyName = "name", powerStatus = "power", controlUrl = "url", status = "level", lastStatusUpdate, parentUserId
    }
    
    init (power source: PowerStatus, imp agentUrl: String, user acctId: UUID, friendly name: String?) {
        powerStatus = source
        controlUrl = agentUrl
        parentUserId = acctId
        friendlyName = name ?? "Toasty Fireplace"
        status = .unknown
        lastStatusUpdate = nil
    }

    func uncertainty () -> Int? {
        guard let lastUpdate = lastStatusUpdate else {return nil}
        let milliSecondsElapsed:Int = Int(lastUpdate.timeIntervalSinceNow * 1000)
        return abs(milliSecondsElapsed)
    }
}

extension Fireplace: PostgreSQLUUIDModel {
    typealias ID = UUID
    static let idKey: IDKey = \.id
}

extension Fireplace: Content {}
extension Fireplace: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.parentUserId, to: \User.id)
        }
    }
}
extension Fireplace: Parameter {}
extension Fireplace {
    var user: Parent<Fireplace, User>? {
        return parent(\.parentUserId?)
    }
    var alexaFireplaces: Children<Fireplace, AlexaFireplace> {
        return children(\.parentFireplaceId)
    }
}

extension Fireplace { //decoding strategy
    init (from decoder: Decoder) throws {
        let allValues = try decoder.container(keyedBy: CodingKeys.self)
        friendlyName = try allValues.decode(String.self, forKey: .friendlyName)
        powerStatus = try allValues.decode(PowerStatus.self, forKey: .powerStatus)
        controlUrl = try allValues.decode(String.self, forKey: .controlUrl)
        status = try allValues.decode(FireLevel.self, forKey: .status)
        id = try allValues.decodeIfPresent(UUID.self, forKey: .id)
        lastStatusUpdate = try allValues.decodeIfPresent(Date.self, forKey: .lastStatusUpdate)
        parentUserId = try allValues.decodeIfPresent(UUID.self, forKey: .parentUserId)
    }
}

extension Fireplace { //encoding strategy
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(friendlyName, forKey: .friendlyName)
        try container.encode(powerStatus, forKey: .powerStatus)
        try container.encode(controlUrl, forKey: .controlUrl)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(lastStatusUpdate, forKey: .lastStatusUpdate)
        try container.encodeIfPresent(parentUserId, forKey: .parentUserId)
    }
}

