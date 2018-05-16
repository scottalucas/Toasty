//
//  LoginWithAmazon.swift
//  App
//
//  Created by Scott Lucas on 5/14/18.
//

import Foundation
import Vapor
import FluentPostgreSQL

struct LWAUserScope:Content {
    var user_id: String
    var email: String?
    var name: String?
    var postal_code: String?
}

struct LWAAccessToken: Content {
    var access_token: String
    var token_type: String
    var expires_in: Int
    var refresh_token: String
}