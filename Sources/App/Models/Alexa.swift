import Foundation
import Vapor
import FluentPostgreSQL

final class AlexaFireplace: Codable {
    var id: UUID? //use as Alexa endpoint ID.
    var status: Status
    var parentFireplaceId: Fireplace.ID //foreign key to the generic fireplace
    var parentAmazonAccountId: AmazonAccount.ID //foreign key to the associated Alexa account
    enum Status: Int, Codable, PostgreSQLEnumType {
        case registered, availableForRegistration, notRegisterable
    }
    init? (childOf fireplace: Fireplace, associatedWith amazonAccount: AmazonAccount) {
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
    let directive:AlexaDirective
}

struct AlexaDirective:Codable {
    let header:AlexaHeader
    let payload:AlexaPayload
    let endpoint:AlexaEndpoint?
}

struct AlexaEvent:Codable {
    let header:AlexaHeader
    let endpoint:AlexaEndpoint
    let payload:AlexaPayload
}

struct AlexaHeader:Codable {
    let namespace: String
    let name:String
    let payloadVersion:String
    let messageId:String
    let correlationToken:String?
}

struct AlexaPayload:Codable {
    let scope:AlexaScope?
}

struct AlexaScope:Codable {
    let type:String?
    let partition:String?
    let userId:String?
    let token:String
}

struct AlexaContext:Codable {
    let properties: [AlexaProperty]?
}

struct AlexaEndpoint:Codable {
    let scope:AlexaScope
    let endpointId:String
    let cookie: [String:String]
}

struct AlexaProperty:Codable {
    let namespace:String
    let name:String
    let value:String
    let timeOfSample: String
    let uncertaintyInMilliseconds:Int
}

struct AlexaTestMessage: Content {
    var testMessage: String
}

struct AlexaDiscoveryRequest: Codable {
    let directive:Directive
    struct Directive: Codable {
        let header: AlexaHeader
        let payload: AlexaPayload
    }
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

