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
    enum InterfaceVersion: String, Codable {
        case latest = "3"
    }
    enum PayloadVersion: String, Codable {
        case latest = "3"
    }
    enum Namespace: String, Codable {
        case basic = "Alexa", discovery = "Alexa.Discovery", power = "Alexa.PowerController", health = "Alexa.EndpointHealth"
        var encodeAsSecondary:Bool {
            switch self {
                case .health:
                    return true
                default:
                    return false
            }
        }
    }
    enum Name: String, Codable {
        case discoverResponse = "Discover.Response", response = "Response", state = "StateReport", error = "ErrorResponse", power = "powerState", connectivity = "connectivity", on = "TurnOn", off = "TurnOff", malformed
    }
    enum EndpointHealth:String {
        case ok = "OK", unreachable = "UNREACHABLE"
    }
}

struct FireplaceConstants: Codable { //set all fireplace constants here
    static let manufacturerName: String = "Toasty Fireplace"
    static let description: String = "Smart home fireplace controller"
    static let displayCategories:[AlexaDisplayCategories] = [.OTHER]
}

// Discovery structs
struct AlexaFireplaceEndpoint: Codable { //use this to create the discovery response
    var endpointId:AlexaFireplace.ID
    var manufacturerName:String = FireplaceConstants.manufacturerName
    var friendlyName:String
    var description:String = FireplaceConstants.description
    var displayCategories:[AlexaDisplayCategories] = FireplaceConstants.displayCategories
    var cookie:[String:String]? = [:]
    var capabilities: [AlexaCapability] = [
        AlexaCapability.init(interface: .basic, version: .latest, supportedProps: nil, reported: nil, retrievable: nil),
        AlexaCapability.init(interface: .power, version: .latest, supportedProps: [["name":"powerState"]], reported: false, retrievable: false)]
    init? (from fireplace:Fireplace) {
        guard let id = fireplace.id else {return nil}
        endpointId = id
        friendlyName = fireplace.friendlyName
    }
}

final class AlexaCapability: Codable {
    let type:Capability = .basic
    let interface: AlexaEnvironment.Namespace
    let version: AlexaEnvironment.InterfaceVersion = .latest
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
    
    enum Capability: String, Codable {
        case basic = "AlexaInterface"
    }
    
    init(interface: AlexaEnvironment.Namespace, version: AlexaEnvironment.InterfaceVersion, supportedProps:[[String:String]]?, reported: Bool?, retrievable: Bool?) {
        self.interface = interface
        properties = Properties(supported: supportedProps, proactivelyReported: reported, retrievable: retrievable)
    }
}

enum AlexaDisplayCategories: String, Codable {
    case ACTIVITY_TRIGGER, CAMERA, DOOR, LIGHT, MICROWAVE, OTHER, SCENE_TRIGGER, SMARTLOCK, SMARTPLUG, SPEAKER, SWITCH, TEMPERATURE_SENSOR, THERMOSTAT, TV
}

struct AlexaDiscoveryResponse: Codable, Content, ResponseEncodable {
    let event:Event
    
    struct Event: Codable {
        let header: AlexaHeader
        let payload: Endpoints
    }
    
    struct Endpoints: Codable {
        var endpoints: [AlexaFireplaceEndpoint] = Array()
        init (using fireplaces: [Fireplace]) {
            for fireplace in fireplaces {
                guard let fp = AlexaFireplaceEndpoint(from: fireplace) else { continue }
                endpoints.append(fp)
            }
        }
    }
    init (msgId: String, sendBack fireplaces: [Fireplace]) {
        let head = AlexaHeader(namespace: .discovery, name: .discoverResponse, payloadVer: .latest, msgId: msgId, corrToken: nil)
        event = Event(header: head, payload: Endpoints(using: fireplaces))
    }
    
}

// Directive structs
struct AlexaMessage: Decodable {
    let directive:AlexaDirective
}

struct AlexaDirective:Decodable {
    let header:AlexaHeader
    let payload:AlexaPayload
    let endpoint:AlexaEndpoint?
}

//event response structures
struct AlexaPowerControllerResponse: Codable, Content, ResponseEncodable {
    let context: AlexaContext
    let event: AlexaEvent
    
    init (requestedVia: AlexaMessage, fireplaceState: ImpFireplaceStatus ) throws {
        var props:[AlexaProperty]
        switch fireplaceState.value {
            case .some(let val):
                props = [
                    AlexaProperty(namespace: .power, name: .power, value: val.rawValue, time: Date(), uncertainty: 500),
                    AlexaProperty(endpointHealth: .ok)]
            case .none:
                props = [AlexaProperty(endpointHealth: .unreachable)]
        }
        var header = requestedVia.directive.header
        header.name = AlexaEnvironment.Name.response
        header.namespace = AlexaEnvironment.Namespace.basic
        guard let endpoint = requestedVia.directive.endpoint else {
            throw AlexaError(.couldNotCreateResponse, file: #file, function: #function, line: #line)
        }
        context = AlexaContext(properties: props)
        event = AlexaEvent(header: header, endpoint: endpoint, payload: AlexaPayload())
    }
}

struct AlexaTestErr: Codable, Content, ResponseEncodable {
    let event: AlexaEvent
}

struct AlexaEvent:Codable {
    let header:AlexaHeader
    let endpoint:AlexaEndpoint
    let payload:AlexaPayload
}

// Common structs
struct AlexaHeader:Codable {
    var namespace: AlexaEnvironment.Namespace
    var name:AlexaEnvironment.Name
    let payloadVersion:AlexaEnvironment.PayloadVersion
    let messageId:String
    let correlationToken:String?
    
    init (namespace: AlexaEnvironment.Namespace, name: AlexaEnvironment.Name, payloadVer: AlexaEnvironment.PayloadVersion, msgId: String, corrToken: String?) {
        self.namespace = namespace
        self.name = name
        payloadVersion = payloadVer
        messageId = msgId
        correlationToken = corrToken
    }
    
    init (msgId: String, corrToken: String?) {
        self.namespace = .basic
        self.name = .response
        payloadVersion = .latest
        messageId = msgId
        correlationToken = corrToken
    }
    
    enum CodingKeys: String, CodingKey {
        case namespace, name, payloadVersion, messageId, correlationToken
    }
}


extension AlexaHeader { //decoding strategy
    init (from decoder: Decoder) throws {
        let allValues = try decoder.container(keyedBy: CodingKeys.self)
        namespace = try allValues.decode(AlexaEnvironment.Namespace.self, forKey: .namespace)
        payloadVersion = try allValues.decode(AlexaEnvironment.PayloadVersion.self, forKey: .payloadVersion)
        messageId = try allValues.decode(String.self, forKey: .messageId)
        correlationToken = try allValues.decodeIfPresent(String.self, forKey: .correlationToken)
        if let nameRaw = try? allValues.decode(AlexaEnvironment.Name.self, forKey: .name) { //to better handle possible unexpected values from Alexa
            name = nameRaw
        } else {
            name = AlexaEnvironment.Name.malformed
        }
    }
}

extension AlexaHeader { //encoding strategy
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(namespace, forKey: .namespace)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(payloadVersion, forKey: .payloadVersion)
        try container.encodeIfPresent(correlationToken, forKey: .correlationToken)
    }
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

extension AlexaPayload { //initializer for Error payloads
    init (err: AlexaErrorValue, reason: String) {
        type = err.rawValue
        message = reason
        scope = nil
    }
}

struct AlexaScope:Codable {
    var token:String
    var type:String? = nil
    var partition:String? = nil
    var userId:String? = nil
    
    init (token: String, type: String?, partition: String?, userId: String?) {
        self.token = token
        self.type = type
        self.partition = partition
        self.userId = userId
    }
    
    init (token: String) {
        self.token = token
        self.type = "BearerToken"
    }
}

struct AlexaContext:Codable {
    var properties: [AlexaProperty]?
    
    init (properties: [AlexaProperty]?) {
        self.properties = properties
    }
}

struct AlexaEndpoint:Codable {
    let endpointId:String
    let scope:AlexaScope?
    let cookie: [String:String]?
    
    init (endpointId id: String, scope: AlexaScope? = nil, cookie: [String:String]? = nil) {
        endpointId = id
        self.scope = scope
        self.cookie = cookie
    }
    
    init (endpointId id: String, accessToken token: String) {
        endpointId = id
        scope = AlexaScope(token: token)
        cookie = nil
    }
    
    init? (directive: AlexaDirective) {
        guard
            let ep = directive.endpoint,
            let scp = ep.scope
        else {return nil}
        endpointId = ep.endpointId
        scope = scp
        cookie = nil
    }
}

struct AlexaProperty: Codable {
    var namespace:AlexaEnvironment.Namespace
    var name:AlexaEnvironment.Name
    var value: String
    var timeOfSample: String?
    var uncertaintyInMilliseconds:Int?
    
    init (namespace: AlexaEnvironment.Namespace, name: AlexaEnvironment.Name, value: String, time: Date?, uncertainty: Int?) {
        self.namespace = namespace
        self.name = name
        self.value = value
        timeOfSample = time?.iso8601 ?? Date().iso8601
        uncertaintyInMilliseconds = uncertainty ?? 200
    }
    
    init (endpointHealth: AlexaEnvironment.EndpointHealth, uncertainty: Int? = nil) {
        namespace = .health
        name = AlexaEnvironment.Name.connectivity
        value = endpointHealth.rawValue
        timeOfSample = Date().iso8601
        uncertaintyInMilliseconds = uncertainty ?? 60000
        
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
        case timeOfSample
        case uncertaintyInMilliseconds
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
        try container.encodeIfPresent(timeOfSample, forKey: .timeOfSample)
        try container.encodeIfPresent(uncertaintyInMilliseconds, forKey: .uncertaintyInMilliseconds)
        if namespace.encodeAsSecondary {
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
        guard let inType = AlexaEnvironment.Namespace(rawValue: ns) else {
            throw AlexaError(.couldNotDecodeProperty , file: #file, function: #function, line: #line)
        }
        namespace = inType
        guard
            let inboundName = try? allValues.decode(String.self, forKey: .name),
            let n = AlexaEnvironment.Name(rawValue: inboundName)
        else {
            throw AlexaError(.couldNotDecodeProperty , file: #file, function: #function, line: #line)
        }
        name = n
        if let v = try? allValues.decode(String.self, forKey: .value) {
            value = v
        } else if let v = try? allValues.decode(Int.self, forKey: .value) {
            value = String(v)
        } else if let v = try? allValues.decode([String:String].self, forKey: .value) {
            guard
                let vStr = v["value"]
                else {
                    throw AlexaError(.couldNotDecodeProperty , file: #file, function: #function, line: #line)
            }
            value = vStr
        } else if let v = try? allValues.decode([String:Int].self, forKey: .value) {
        guard
            let vInt = v["value"]
            else {
                throw AlexaError(.couldNotDecodeProperty , file: #file, function: #function, line: #line)
            }
            value = String(vInt)
        } else {
            throw AlexaError(.couldNotDecodeProperty , file: #file, function: #function, line: #line)        }
    }
}


//struct AlexaFireplaceStatus: Codable, Content { //for communication to Alexa
//    let status:Status
//    enum Status: String, Codable {
//        case ON, OFF, NotAvailable
//    }
//}

//Error structs


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

struct AlexaErrorResponse: Codable, Content, ResponseEncodable {
    var event: AlexaEvent
    init (requestedVia: AlexaMessage, errType eType: AlexaErrorValue, message msg: String) throws {
        var header = requestedVia.directive.header
        header.name = AlexaEnvironment.Name.error
        header.namespace = AlexaEnvironment.Namespace.basic
        guard let endpoint = requestedVia.directive.endpoint else {
            throw AlexaError(.couldNotCreateResponse, file: #file, function: #function, line: #line)
        }
        let payload = AlexaPayload.init(err: eType, reason: msg)
        event = AlexaEvent(header: header, endpoint: endpoint, payload: payload)
    }
    
    init(event: AlexaEvent) {
        self.event = event
    }
}

struct AlexaStateReport: Codable, Content, ResponseEncodable {
    var context: AlexaContext
    var event: AlexaEvent
    
    init? (forFireplace fireplace: Fireplace, stateRequest: AlexaMessage) {
        guard
            let id = fireplace.id?.uuidString,
            let cToken = stateRequest.directive.header.correlationToken,
            let aToken = stateRequest.directive.endpoint?.scope?.token
            else {return nil}
        let msgId = stateRequest.directive.header.messageId
        let header = AlexaHeader(namespace: .basic, name: .state, payloadVer: .latest, msgId: msgId, corrToken: cToken)
        let endpoint = AlexaEndpoint(endpointId: id, accessToken: aToken)
        let payload = AlexaPayload()
        event = AlexaEvent(header: header, endpoint: endpoint, payload: payload)
        var properties:[AlexaProperty]
        switch fireplace.status {
            case .some(let val):
                properties = [
                    AlexaProperty(endpointHealth: .ok),
                    AlexaProperty(namespace: .power, name: .power, value: val, time: Date(), uncertainty: fireplace.uncertainty() ?? 60000)
                ]
            case .none:
                properties = [
                    AlexaProperty(endpointHealth: .unreachable)
                ]
        }
        context = AlexaContext(properties: properties)
    }
    
    init? (_ fpUuid: String, stateRequest: AlexaMessage) {
        guard
            let cToken = stateRequest.directive.header.correlationToken,
            let aToken = stateRequest.directive.endpoint?.scope?.token
            else {return nil}
        let msgId = stateRequest.directive.header.messageId
        let header = AlexaHeader(namespace: .basic, name: .response, payloadVer: .latest, msgId: msgId, corrToken: cToken)
        let endpoint = AlexaEndpoint(endpointId: fpUuid, accessToken: aToken)
        let payload = AlexaPayload()
        event = AlexaEvent(header: header, endpoint: endpoint, payload: payload)
        context = AlexaContext(properties: [])
    }
    
    mutating func updateProperties (fireplaceStatus: ImpFireplaceStatus) {
        switch fireplaceStatus.ack {
        case .acceptedOff:
            context.properties = [
                AlexaProperty(endpointHealth: .ok, uncertainty: fireplaceStatus.uncertaintyInMilliseconds),
                AlexaProperty(namespace: .power, name: .power, value: ImpFireplaceStatus.ValueMessage.OFF.rawValue, time: Date(), uncertainty: fireplaceStatus.uncertaintyInMilliseconds)
            ]
        case .acceptedOn:
            context.properties = [
                AlexaProperty(endpointHealth: .ok, uncertainty: fireplaceStatus.uncertaintyInMilliseconds),
                AlexaProperty(namespace: .power, name: .power, value: ImpFireplaceStatus.ValueMessage.ON.rawValue, time: Date(), uncertainty: fireplaceStatus.uncertaintyInMilliseconds)
            ]
        default:
            context.properties = [AlexaProperty(endpointHealth: .unreachable)]
        }
    return
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
