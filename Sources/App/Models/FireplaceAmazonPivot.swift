import Foundation
import Vapor
import FluentPostgreSQL

struct FireplaceAmazonPivot: Codable, PostgreSQLUUIDModel {
	typealias Database = PostgreSQLDatabase
	var id: UUID?
	var fireplaceId: Fireplace.ID
	var amazonAccountId: AmazonAccount.ID
}

extension FireplaceAmazonPivot: PostgreSQLUUIDPivot, ModifiablePivot {
	
	typealias Left = Fireplace
	typealias Right = AmazonAccount
	
	static let leftIDKey: LeftIDKey = \.fireplaceId
	static let rightIDKey: RightIDKey = \.amazonAccountId
	
	init (_ fireplace: Fireplace, _ account: AmazonAccount) throws {
		self.fireplaceId = try fireplace.requireID()
		self.amazonAccountId = try account.requireID()
	}
}

extension Fireplace {
	var amazonAccounts: Siblings<Fireplace, AmazonAccount, FireplaceAmazonPivot> {
		return siblings()
	}
}

extension AmazonAccount {
	var fireplaces: Siblings<AmazonAccount, Fireplace, FireplaceAmazonPivot> {
		return siblings()
	}
}

extension FireplaceAmazonPivot:Content {}
extension FireplaceAmazonPivot:Migration {
	static func prepare(
		on connection: PostgreSQLConnection
		) -> Future<Void> {
		return Database.create(self, on: connection) { builder in
			try addProperties(to: builder)
			builder.reference(
				from: \.fireplaceId,
				to: \Fireplace.id,
				onDelete: .cascade)
			builder.reference(
				from: \.amazonAccountId,
				to: \AmazonAccount.id,
				onDelete: .cascade)
		}
	}
}
extension FireplaceAmazonPivot:Parameter {}
