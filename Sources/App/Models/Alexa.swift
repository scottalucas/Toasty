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
    static let capbilityType:String = "AlexaInterface"
    static let interfaceVersion: String = "3"
    static let discoveryNamespace: String = "Alexa.Discovery"
    static let discoveryResponseHeaderName: String = "Discover.Response"
    enum SmartHomeInterface: String {
        case discovery = "Alexa.Discovery", discoveryResponse = "Discover.Response", fireplace = "Alexa.PowerController", health = "Alexa.EndpointHealth"
    }
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
    let type: String = AlexaEnvironment.capbilityType
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

enum AlexaErrorValue: String {
    case inOperation = "ALREADY_IN_OPERATION"
    case bridgeUnreachable = "BRIDGE_UNREACHABLE"
    case busy = "ENDPOINT_BUSY"
    case lowPower = "ENDPOINT_LOW_POWER"
    case endpointUnreachable = "ENDPOINT_UNREACHABLE"
    case expiredCredentials = "EXPIRED_AUTHORIZATION_CREDENTIAL"
    case fwOutOfDate = "FIRMWARE_OUT_OF_DATE"
    case hwMalfunction = "HARDWARE_MALFUNCTION"
    case internalError = "INTERNAL_ERROR"
    case invalidCredential = "INVALID_AUTHORIZATION_CREDENTIAL"
    case invalidDirective = "INVALID_DIRECTIVE"
    case invalidValue = "INVALID_VALUE"
    case noSuchEndpoint = "NO_SUCH_ENDPOINT"
    case notSupported = "NOT_SUPPORTED_IN_CURRENT_MODE"
    case notInOperation = "NOT_IN_OPERATION"
    case powerLevelNotSupported = "POWER_LEVEL_NOT_SUPPORTED"
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
    case tempValueOutOfRange = "TEMPERATURE_VALUE_OUT_OF_RANGE"
    case valueOutOfRange = "VALUE_OUT_OF_RANGE"
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

// Directive structs
struct AlexaMessage:Content {
    let directive:AlexaDirective
}

struct AlexaDirective:Codable {
    let header:AlexaHeader
    let payload:AlexaPayload
    let endpoint:AlexaEndpoint?
}

//event response structures
struct AlexaResponse: Codable, Content, ResponseEncodable {
    let context: AlexaContext
    let event: AlexaEvent
}

struct AlexaEvent:Codable {
    let header:AlexaHeader
    let endpoint:AlexaEndpoint
    let payload:AlexaPayload
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
    var scope:AlexaScope? = nil
    var type:String? = nil
    var message:String? = nil
    
    enum CodingKeys: String, CodingKey {
        case scope, type, message
    }
    
}

extension AlexaPayload { //encoding strategy
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(message, forKey: .message)
    }
}

extension AlexaPayload { //decoding strategy
    init (from decoder: Decoder) throws {
        let allValues = try decoder.container(keyedBy: CodingKeys.self)
        scope = try allValues.decodeIfPresent(AlexaScope.self, forKey: .scope)
        type = try allValues.decodeIfPresent(String.self, forKey: .type)
        message = try allValues.decodeIfPresent(String.self, forKey: .message)
    }
}

struct AlexaErrorPayload: Encodable {
    var type: String
    var message: String
    
    init (err: AlexaErrorValue, reason: String) {
        type = err.rawValue
        message = reason
    }
    
    enum CodingKeys: String, CodingKey {
        case type, message
    }
}

struct AlexaScope:Codable {
    let token:String
    let type:String? = nil
    let partition:String? = nil
    let userId:String? = nil
}

struct AlexaContext:Codable {
    let properties: [AlexaProperty]?
}

struct AlexaEndpoint:Codable {
    let endpointId:String
    let scope:AlexaScope?
    let cookie: [String:String]?
    
    init (using id: String, scope: AlexaScope? = nil, cookie: [String:String]? = nil) {
        endpointId = id
        self.scope = scope
        self.cookie = cookie
    }
}

struct AlexaProperty: Codable {
    private var namespaceType: Interface
    var namespace:String {
        return namespaceType.rawValue
    }
    var name:String
    var value: String
    var timeOfSample: String?
    var uncertaintyInMilliseconds:Int?
    
    init (namespace: Interface, name: String, value: String, time: Date?, uncertainty: Int?) {
        namespaceType = namespace
        self.name = name
        self.value = value
        timeOfSample = time?.iso8601 ?? Date().iso8601
        uncertaintyInMilliseconds = uncertainty ?? 200
    }
    
    enum Interface: String {
        case power = "Alexa.PowerController", health = "Alexa.EndpointHealth"
        var encodeAsSecondary:Bool {
            switch self {
            case .power:
                return false
            case .health:
                return true
            }
        }
    }
    enum CodingKeys: String, CodingKey {
        case namespace
        case name
        case value
    }
    
    enum ValueKeys: String, CodingKey {
        case value
    }
}

extension AlexaProperty { //encoding strategy
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(namespace, forKey: .namespace)
        try container.encode(name, forKey: .name)
        if namespaceType.encodeAsSecondary {
            var secondaryValueInfo = container.nestedContainer(keyedBy: ValueKeys.self, forKey: .value)
            try secondaryValueInfo.encode(value, forKey: .value)
        } else {
            try container.encode(value, forKey: .value)
        }
    }
}

extension AlexaProperty { //decoding strategy
    init (from decoder: Decoder) throws {
        let allValues = try decoder.container(keyedBy: CodingKeys.self)
        let ns = try allValues.decode(String.self, forKey: .namespace)
        guard let inType = Interface(rawValue: ns) else {
            throw Abort(.notFound, reason: "Could not decode property, unknown interface type.")
        }
        namespaceType = inType
        name = try allValues.decode(String.self, forKey: .name)
        do {
            value = try allValues.decode(String.self, forKey: .value)
        } catch {
            value = String(try allValues.decode(Int.self, forKey: .value))
        }
    }
}

//Error structs
struct AlexaError: Codable, Content, ResponseEncodable {
    var event: AlexaEvent
    
    init(msgId: String, corrToken: String, endpoint: String, errType: AlexaErrorValue, message: String) {
        let header = AlexaHeader(namespace: AlexaEnvironment.basicInterface, name: "ErrorResponse", payloadVersion: AlexaEnvironment.interfaceVersion, messageId: msgId, correlationToken: corrToken)
        let endpoint = AlexaEndpoint.init(using: endpoint)
        var payload = AlexaPayload()
            payload.type = errType.rawValue
            payload.message = message
        event = AlexaEvent(header: header, endpoint: endpoint, payload: payload)
    }
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

extension Formatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}
extension Date {
    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}

extension String {
    var dateFromISO8601: Date? {
        return Formatter.iso8601.date(from: self)   // "Mar 22, 2017, 10:22 AM"
    }
}
