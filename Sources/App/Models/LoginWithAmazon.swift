//
//  LoginWithAmazon.swift
//  App
//
//  Created by Scott Lucas on 5/14/18.
//

import Foundation
import Vapor
import FluentPostgreSQL

//parameter types
struct LWAAccessAuth : Content {
    var code:String
    var state:String
    var scope:String
}

struct LWAUserScope:Content {
    var user_id: String
    var email: String?
    var name: String?
    var postal_code: String?
}
//grant_type    REQUIRED. The type of access grant requested. Must be Authorization_code.
//code    REQUIRED. The code returned by the authorization request.
//redirect_uri    REQUIRED. If you provided a redirect_uri for the authorization request, you must pass the same redirect_uri here. If you used the Login with Amazon SDK for JavaScript for the authorization request, you do not need to pass a redirect_uri here.
//client_id    REQUIRED. The client identifier. This is set when you register your website as a client. For more information, see Client Identifier.
//client_secret    REQUIRED. The secret value assigned to the client during registration.

struct LWAAccessRequest: Content {
    static let grant_type: String = "Authorization_code"
    var code: String
    var redirect_uri: String
    var client_id: String
    var client_secret: String
}

struct LWAAccessToken: Content {
    var access_token: String
    var token_type: String
    var expires_in: Int
    var refresh_token: String
}
