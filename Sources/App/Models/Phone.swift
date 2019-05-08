import Foundation
import Vapor
import FluentPostgreSQL

struct Phone: Codable {
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
	
	init(phoneId: UUID) {
		id = phoneId
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


extension Phone: PostgreSQLUUIDModel {}
extension Phone: Content {}
extension Phone: Migration {}
extension Phone: Parameter {}



extension Phone {
	static func setUpUnassignedPhone (on app: Application) -> Future<String> {
		let unassignedPhoneId = UUID.init("FFFFFFFF-0000-0000-0000-000000000000")!
		return app.withNewConnection(to: .psql) {
			conn in
			return Phone.query(on: conn)
				.filter ( \.id == unassignedPhoneId )
				.first()
				.flatMap(to: Phone.self) { optUser in
					guard optUser == nil else { throw ImpError(.foundDefaultUser) }
					return Phone.init(name: "Default user", username: "default").save(on: conn)
				}.flatMap () { user in
					let queryString = """
					UPDATE "Phone" SET id = '\(unassignedPhoneId.uuidString)' WHERE id = '\(user.id!.uuidString)';
					"""
					return conn.simpleQuery(queryString).transform(to: "done")
			}
		}
	}
}

