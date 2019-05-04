import Foundation
import Vapor
import FluentPostgreSQL

struct User: Codable {
	var id: UUID?
	var name: String?
	var username: String?
	static let defaultUserId = UUID.init("FFFFFFFF-0000-0000-0000-000000000000")!
	
	
	init() {
		name = nil
		username = nil
	}
	
	init(name: String, username: String) {
		self.name = name
		self.username = username
	}
	
	init(userId: UUID) {
		id = userId
	}
	
	mutating func setName (_ name: String) {
		self.name = name
		return
	}
	
	mutating func setUsername (_ userName: String) {
		self.username = userName
		return
	}
}


extension User: PostgreSQLUUIDModel {}
extension User: Content {}
extension User: Migration {}
extension User: Parameter {}



extension User {
	static func setUpUnassignedUserAccount (on app: Application) -> Future<String> {
		let unassignedUserId = UUID.init("FFFFFFFF-0000-0000-0000-000000000000")!
		return app.withNewConnection(to: .psql) {
			conn in
			return User.query(on: conn)
				.filter ( \.id == unassignedUserId )
				.first()
				.flatMap(to: User.self) { optUser in
					guard optUser == nil else { throw ImpError(.foundDefaultUser) }
					return User.init(name: "Default user", username: "default").save(on: conn)
				}.flatMap () { user in
					let queryString = """
					UPDATE "User" SET id = '\(unassignedUserId.uuidString)' WHERE id = '\(user.id!.uuidString)';
					"""
					return conn.simpleQuery(queryString).transform(to: "done")
			}
		}
	}
}

