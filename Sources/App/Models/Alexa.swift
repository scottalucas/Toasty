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

struct AlexaEnvironment: Codable {
    static let basicInterface: String = "Alexa"
    static let type:String = "AlexaInterface"
    static let interfaceVersion: String = "3"
    static let discoveryNamespace: String = "Alexa.Discovery"
    static let discoveryResponseHeaderName: String = "Discover.Response"
}

// Discovery structs
struct AlexaFireplaceEndpoint: Codable { //use this to create the discovery response
    var endpointId:AlexaFireplace.ID
    var manufacturerName:String = "Toasty Fireplace"
    var friendlyName:String
    var description:String = "Smart home fireplace controller"
    var displayCategories:[AlexaDisplayCategories] = [.OTHER]
    var cookie:[String:String]? = [:]
    var capabilities: [AlexaCapability] = [
        AlexaCapability.init(interface: AlexaEnvironment.basicInterface, version: AlexaEnvironment.interfaceVersion, supportedProps: nil, reported: nil, retrievable: nil),
        AlexaCapability.init(interface: "Alexa.PowerController", version: AlexaEnvironment.interfaceVersion, supportedProps: [["name":"powerState"]], reported: false, retrievable: false)]
    init? (from fireplace:Fireplace) {
        guard let id = fireplace.id else {return nil}
        endpointId = id
        friendlyName = fireplace.friendlyName
    }
}

final class AlexaCapability: Codable {
    let type: String = AlexaEnvironment.type
    let interface: String
    let version: String = AlexaEnvironment.interfaceVersion
    let properties: Properties?
    struct Properties: Codable {
        let supported: [[String:String]]?
        let proactivelyReported: Bool?
        let retrievable: Bool?
        init? (supported: [[String:String]]?, proactivelyReported: Bool?, retrievable: Bool?) {
            if supported == nil && proactivelyReported == nil && retrievable == nil {return nil}
            self.supported = supported
            self.proactivelyReported = proactivelyReported
            self.retrievable = retrievable
        }
    }
    
    init(interface: String, version: String, supportedProps:[[String:String]]?, reported: Bool?, retrievable: Bool?) {
        self.interface = interface
        properties = Properties(supported: supportedProps, proactivelyReported: reported, retrievable: retrievable)
    }
}

enum AlexaDisplayCategories: String, Codable {
    case ACTIVITY_TRIGGER, CAMERA, DOOR, LIGHT, MICROWAVE, OTHER, SCENE_TRIGGER, SMARTLOCK, SMARTPLUG, SPEAKER, SWITCH, TEMPERATURE_SENSOR, THERMOSTAT, TV
}

struct AlexaDiscoveryRequest: Codable {
    let directive:Directive
    struct Directive: Codable {
        let header: AlexaHeader
        let payload: AlexaPayload
    }
}

struct AlexaDiscoveryResponse: Codable, Content {
    let event:Event
    
    struct Event: Codable {
        let header: AlexaHeader
        let payload: Endpoints
    }
    
    struct Endpoints: Codable {
        var endpoints: [AlexaFireplaceEndpoint] = Array()
        init? (using fireplaces: [Fireplace]) {
            for fireplace in fireplaces {
                guard let fp = AlexaFireplaceEndpoint(from: fireplace) else { return nil}
                endpoints.append(fp)
            }
        }
    }
    
    init? (msgId: String, sendBack fireplaces: [Fireplace]) {
        guard let endPts = Endpoints(using: fireplaces) else {return nil}
        let head = AlexaHeader(namespace: AlexaEnvironment.discoveryNamespace, name: AlexaEnvironment.discoveryResponseHeaderName, payloadVersion: AlexaEnvironment.interfaceVersion, messageId: msgId, correlationToken: nil)
        event = Event(header: head, payload: endPts)
    }
    
}

// Event structs
struct AlexaMessage:Content {
    let directive:AlexaDirective
}

struct AlexaEvent:Codable {
    let header:AlexaHeader
    let endpoint:AlexaEndpoint
    let payload:AlexaPayload
}

struct AlexaDirective:Codable {
    let header:AlexaHeader
    let payload:AlexaPayload
    let endpoint:AlexaEndpoint?
}

final class AlexaToastyPowerControllerInterfaceRequest: Codable {
    var header:Header
    var endpoint:InboundEndpoint
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
}

// Common structs
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

struct InboundEndpoint: Codable {
    let scope: Scope
    let endpointId: String
    let cookie: [String:String]
    struct Scope: Codable {
        let type: String = "BearerToken"
        let token: String
    }
}

