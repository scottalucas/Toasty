//
//  Session.swift
//  Toasty
//
//  Created by Scott Lucas on 5/24/18.
//

import Foundation
import Vapor
import FluentPostgreSQL

struct SessionData: PostgreSQLModel {
    var id:Int?
    var fireplaces:[Fireplace]?
    var expiration:Date?
}

extension SessionData: Content {}
extension SessionData: Migration {}
