import Foundation
import Vapor
import FluentPostgreSQL

struct Fireplace: Codable, Hashable {
//	var id:UUID?
	var deviceid: String // unique to each fireplace device, key
	var friendlyName:String
	var powerStatus:PowerStatus
	var controlUrl:String //unique to each fireplace agent
	var status:FireLevel //flame is on or off
	var lastStatusUpdate: Date?
//	var parentUserId:User.ID?

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
        case friendlyName = "name", powerStatus = "power", controlUrl = "url", deviceid, status = "level", lastStatusUpdate, parentUserId
    }
    
	init (power source: PowerStatus, imp agentUrl: String, id deviceId: String, friendly name: String?) {
		powerStatus = source
		controlUrl = agentUrl
		deviceid = deviceId
//		parentUserId = acctId
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

extension Fireplace: PostgreSQLStringModel {
	var id: String? {
		get {
			return deviceid
		}
		set(newValue) {
			guard let new = newValue else {return}
			deviceid = new
		}
	}
	
	typealias ID = String
	static let idKey: IDKey = \.id
}

extension Fireplace: Content {}
extension Fireplace: Migration {}
extension Fireplace: Parameter {}

extension Fireplace { //decoding strategy
	init (from decoder: Decoder) throws {
		let allValues = try decoder.container(keyedBy: CodingKeys.self)
		friendlyName = try allValues.decode(String.self, forKey: .friendlyName)
		powerStatus = try allValues.decode(PowerStatus.self, forKey: .powerStatus)
		controlUrl = try allValues.decode(String.self, forKey: .controlUrl)
		deviceid = try allValues.decode(String.self, forKey: .deviceid)
		status = try allValues.decode(FireLevel.self, forKey: .status)
		lastStatusUpdate = try allValues.decodeIfPresent(Date.self, forKey: .lastStatusUpdate)
//		parentUserId = try allValues.decodeIfPresent(UUID.self, forKey: .parentUserId)
	}
}

extension Fireplace { //encoding strategy
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(friendlyName, forKey: .friendlyName)
		try container.encode(powerStatus, forKey: .powerStatus)
		try container.encode(controlUrl, forKey: .controlUrl)
		try container.encode(deviceid, forKey: .deviceid)
		try container.encode(status, forKey: .status)
		try container.encodeIfPresent(lastStatusUpdate, forKey: .lastStatusUpdate)
//		try container.encodeIfPresent(parentUserId, forKey: .parentUserId)
	}
}

