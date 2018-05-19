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


struct LWAAccessRequest: Content {
    var grant_type: String
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
