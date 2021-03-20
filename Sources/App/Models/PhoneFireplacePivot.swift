//
//  UserFireplace.swift
//  Toasty
//
//  Created by Scott Lucas on 4/27/19.
//

import Foundation
import Vapor
import FluentPostgreSQL


/*
This class maps users to fireplaces. These can be many to many relationships.
*/
struct UserFireplacePivot {
	
	var id: UUID? //auto assigned when record is created
	var phoneId: Phone.ID //phone vendor uuid
	var fireplaceId: Fireplace.ID //fireplace id from Imp
}

extension UserFireplacePivot: PostgreSQLUUIDPivot, ModifiablePivot {
	
	typealias Left = Phone
	typealias Right = Fireplace
	
	static let leftIDKey: LeftIDKey = \.phoneId
	static let rightIDKey: RightIDKey = \.fireplaceId
	
	init (_ phone: Phone, _ fireplace: Fireplace) throws {
		self.phoneId = try phone.requireID()
		self.fireplaceId = try fireplace.requireID()
	}
}

extension Phone {
	var fireplaces: Siblings<Phone, Fireplace, UserFireplacePivot> {
		return siblings()
	}
}

extension Fireplace {
	var phones: Siblings<Fireplace, Phone, UserFireplacePivot> {
		return siblings()
	}
}

extension UserFireplacePivot: PostgreSQLUUIDModel {
	typealias Database = PostgreSQLDatabase
}
extension UserFireplacePivot: Content {}
extension UserFireplacePivot: Migration {
	static func prepare(
		on connection: PostgreSQLConnection
		) -> Future<Void> {
		return Database.create(self, on: connection) { builder in
			try addProperties(to: builder)
			builder.reference(
				from: \.phoneId,
				to: \Phone.id,
				onDelete: .cascade)
			builder.reference(
				from: \.fireplaceId,
				to: \Fireplace.deviceid,
				onDelete: .cascade)
		}
	}
}
extension UserFireplacePivot: Parameter {}

