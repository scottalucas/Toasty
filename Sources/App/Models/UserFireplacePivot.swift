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
	var userId: User.ID //phone vendor uuid
	var fireplaceId: Fireplace.ID //fireplace id from Imp
}

extension UserFireplacePivot: PostgreSQLUUIDPivot, ModifiablePivot {
	
	typealias Left = User
	typealias Right = Fireplace
	
	static let leftIDKey: LeftIDKey = \.userId
	static let rightIDKey: RightIDKey = \.fireplaceId
	
	init (_ user: User, _ fireplace: Fireplace) throws {
		self.userId = try user.requireID()
		self.fireplaceId = try fireplace.requireID()
	}
}

extension User {
	var fireplaces: Siblings<User, Fireplace, UserFireplacePivot> {
		return siblings()
	}
}

extension Fireplace {
	var users: Siblings<Fireplace, User, UserFireplacePivot> {
		return siblings()
	}
}

extension UserFireplacePivot: PostgreSQLUUIDModel {}
extension UserFireplacePivot: Content {}
extension UserFireplacePivot: Migration {
	static func prepare(
		on connection: PostgreSQLConnection
		) -> Future<Void> {
		return Database.create(self, on: connection) { builder in
			try addProperties(to: builder)
			builder.reference(
				from: \.userId,
				to: \User.id,
				onDelete: .cascade)
			builder.reference(
				from: \.fireplaceId,
				to: \Fireplace.deviceid,
				onDelete: .cascade)
		}
	}
}
extension UserFireplacePivot: Parameter {}

