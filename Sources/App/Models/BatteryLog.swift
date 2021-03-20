//
//  BatteryLog.swift
//  App
//
//  Created by Scott Lucas on 8/8/19.
//

import Foundation
import Vapor
import FluentPostgreSQL

struct BatteryLog: Codable {
    var id: UUID?
    var fireplaceId: String
    var timestamp: Date
    var batteryLevel: Float
}

extension BatteryLog: PostgreSQLUUIDModel {
	typealias Database = PostgreSQLDatabase
}
extension BatteryLog: Content {}
extension BatteryLog: Migration {}
