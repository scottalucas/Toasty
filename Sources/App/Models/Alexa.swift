import Foundation
import Vapor
import FluentPostgreSQL

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

final class AlexaAccount: Codable {
    var toastyUserID:UUID
    var accessToken:String? //this is the Alexa access token
    var refreshToken:String?
    var id: Int?
    
    init (toastyAccountID: UUID) {
        toastyUserID = toastyAccountID
    }
}

extension AlexaAccount:PostgreSQLModel {}
extension AlexaAccount:Content {}
extension AlexaAccount:Migration {}
extension AlexaAccount:Parameter {}
extension AlexaAccount {
    var user: Parent<AlexaAccount, User> {
        return parent(\.toastyUserID)
    }
}
