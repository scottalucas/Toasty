import Foundation
import Vapor
import FluentPostgreSQL

final class AlexaFireplace: Codable {
    var id: UUID? //use as Alexa endpoint ID.
    var status: Status
    var parentFireplaceId: Fireplace.ID //foreign key to the generic fireplace
    var parentAmazonAccountId: AmazonAccount.ID //foreign key to the associated Alexa account
    enum Status: Int, Codable {
        case registered, availableForRegistration, notRegisterable
    }
    init? (childOf fireplace:Fireplace, associatedWith amazonAccount: AmazonAccount) {
        guard let fpId = fireplace.id, let azId = amazonAccount.id else { return nil }
        parentFireplaceId = fpId
        parentAmazonAccountId = azId
        self.status = (fireplace.powerSource != .line) ? Status.notRegisterable : Status.availableForRegistration
    }
    
    func didCreate(on connection: PostgreSQLConnection) throws -> EventLoopFuture<AlexaFireplace> {
        logger.info("Created new Alexa Fireplace\n\tid: \(id?.uuidString ?? "none")\n\tParent AZ account: \(parentAmazonAccountId)")
        return Future.map(on: connection) {self}
    }
}

struct AlexaFireplaceForDiscovery: Codable { //use this to create the discovery response
    var endpointId:AlexaFireplace.ID
    var manufacturerName:String = "Toasty Fireplace"
//    var friendlyName:String
    var description:String = "Smart home fireplace controller"
    var displayCategories:[AlexaDisplayCategories] = [.SWITCH]
    var cookie:[String:String] = [:]
    var capabilities: [AlexaCapabilities] = [AlexaCapabilities.init(interface: "Alexa.PowerController", version: "3", supportedProps: [["name":"powerState"]], reported: false, retrievable: false)]
    init? (from fireplace:AlexaFireplace) {
        guard let id = fireplace.id else {return nil}
        endpointId = id
    }
}

final class AlexaCapabilities: Codable {
    var type: String = "AlexaInterface"
    var interface: String
    var version: String
    var properties: Properties
    struct Properties: Codable {
        var supported: [[String:String]]?
        var proactivelyReported: Bool?
        var retrievable: Bool?
    }
    
    init(interface: String, version: String, supportedProps:[[String:String]], reported: Bool, retrievable: Bool) {
        self.interface = interface
        self.version = version
        properties = Properties(supported: supportedProps, proactivelyReported: reported, retrievable: retrievable)
    }
}

enum AlexaDisplayCategories: String, Codable {
    case ACTIVITY_TRIGGER, CAMERA, DOOR, LIGHT, MICROWAVE, OTHER, SCENE_TRIGGER, SMARTLOCK, SMARTPLUG, SPEAKER, SWITCH, TEMPERATURE_SENSOR, THERMOSTAT, TV
}

struct AlexaMessage:Content {
    var directive:AlexaDirective
}

struct AlexaDirective:Codable {
    var header:AlexaHeader
    var payload:AlexaPayload
    var endpoint:AlexaEndpoint?
}

struct AlexaEvent:Codable {
    var header:AlexaHeader
    var endpoint:AlexaEndpoint
    var payload:AlexaPayload
}

struct AlexaHeader:Codable {
    var namespace: String
    var name:String
    var payloadVersion:String
    var messageId:String
    var correlationToken:String?
}

struct AlexaContext:Codable {
    var properties: [AlexaProperty]?
}

struct AlexaEndpoint:Codable {
    var scope:AlexaScope
    var endpointId:String
    var cookie: [String:String]
}

struct AlexaScope:Codable {
    var type:String?
    var partition:String?
    var userId:String?
    var token:String
}

struct AlexaProperty:Codable {
    var namespace:String
    var name:String
    var value:String
    var timeOfSample: String
    var uncertaintyInMilliseconds:Int
}

struct AlexaPayload:Codable {
    var scope:AlexaScope?
}

struct AlexaTestMessage: Content {
    var testMessage: String
}




final class AlexaToastyPowerControllerInterfaceRequest: Codable {
    var header:Header
    var endpoint:Endpoint
    var payload: [String:String]?
    
    struct Header:Codable {
        var namespace:String = "Alexa.PowerController"
        var name: Name
        var payloadVersion: String
        var messageId: String
        var correlationToken: String
        enum Name: String, Codable {
            case TurnOn = "TurnOn"
            case TurnOff = "TurnOff"
            func execute () {
                switch self {
                case .TurnOn:
                    break
                //insert turn on url here
                case .TurnOff:
                    break
                    //insert turn off url here
                }
            }
        }
    }
    struct Endpoint: Codable {
        var scope: Scope
        var endpointId: String
        var cookie: [String:String]
        struct Scope: Codable {
            var type: String = "BearerToken"
            var token: String
        }
    }
}

extension AlexaFireplace:PostgreSQLUUIDModel {}
extension AlexaFireplace:Content {}
extension AlexaFireplace:Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            try builder.addReference(from: \.parentAmazonAccountId, to: \AmazonAccount.id)
            try builder.addReference(from: \.parentFireplaceId, to: \Fireplace.id)
        }
    }
}
extension AlexaFireplace:Parameter {}
extension AlexaFireplace {
    var parentFireplace: Parent<AlexaFireplace, Fireplace> {
        return parent(\.parentFireplaceId)
    }
    var parentAmazonAccount: Parent<AlexaFireplace, AmazonAccount> {
        return parent(\.parentAmazonAccountId)
    }
}
