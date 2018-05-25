//
//  LoginWithAmazon.swift
//  App
//
//  Created by Scott Lucas on 5/14/18.
//

import Foundation
import Vapor
import FluentPostgreSQL

final class AmazonAccount:Codable, Model {
    var id: UUID?
    var amazonUserId: String
    var email: String?
    var name: String?
    var postalCode: String?
    var userId: User.ID? //foreign key to main user account
    var user: Parent<AmazonAccount, User>? {
        return parent(\.userId)
    }
    
    init (with lwaScope: LWAUserScope, userId: User.ID?) {
        amazonUserId = lwaScope.user_id
        email = lwaScope.email
        name = lwaScope.name
        postalCode = lwaScope.postal_code
        self.userId = userId
    }
}

extension AmazonAccount: PostgreSQLUUIDModel {}
extension AmazonAccount: Content {}
extension AmazonAccount: Migration {}
extension AmazonAccount: Parameter {}

struct LWAUserScope:Content {
    var user_id: String
    var email: String?
    var name: String?
    var postal_code: String?
}

enum LWAUserScopeError : String {
    case success = "Success"
    case invalidRequest = "invalid_request"
    case invalidToken = "invalid_token"
    case insufficientScope = "insufficient_scope"
    case serverError = "ServerError"
    
    func desc () -> String {
    switch self {
        case .success:
            return "The request was successful."
        case .invalidRequest:
            return "The request is missing a required parameter or otherwise malformed."
        case .invalidToken:
            return "The access token provided is expired, revoked, malformed, or invalid for other reasons."
        case .insufficientScope:
            return "The access token provided does not have access to the required scope."
        case .serverError:
            return "The Amazon server encountered a runtime error."
        }
    }
}

struct LWAAuthTokenResponse: Content {
    var code:String //access code
    var state:String
    
    enum CodingKeys : String, CodingKey {
        case code = "accessCode"
        case state = "sessionId"
    }
}

struct LWAAuthTokenResponseError: Content {
    var error:String
    var error_description:String
    var error_uri:String
    var state:String?
}

struct LWAAccessTokenRequest: Content {
    var grant_type: String
    var code: String
    var redirect_uri: String
    var client_id: String
    var client_secret: String
    
    init (codeIn: String, redirectUri: String, clientId: String, clientSecret: String) {
        grant_type = "authorization_code"
        code = codeIn
        redirect_uri = redirectUri
        client_id = clientId
        client_secret = clientSecret
    }
}

struct LWAAccessTokenGrant: Content {
    var access_token: String
    var token_type: String
    var expires_in: Int
    var refresh_token: String
}

struct LWAAccessTokenGrantError: Content {
    var error:String
    var error_description: String
    var error_uri: String
}

struct LWASites {
    static let tokens:String = "https://api.amazon.com/auth/o2/token"
    static let users:String = "https://api.amazon.com/user/profile"
}

struct LWATokenRequestConfig {
    static let profile:String = "profile:user_id"
    static let interactive:String = "auto"
    static let responseType:String = "code"
}
