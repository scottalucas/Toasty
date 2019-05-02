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
	static func getAmazonAccount (usingToken token: String, on req: Request) throws -> Future<AmazonAccount> {
		let logger = try req.make(Logger.self)
		guard let client = try? req.make(Client.self) else {
			throw LoginWithAmazonError(.couldNotInitializeAccount, file: #file, function: #function, line: #line)
		}
		if token == "test" { //for testing on
			return AmazonAccount.query(on: req).first()
				.map (to: AmazonAccount.self) { optAcct in
					guard let acct = optAcct else {
						throw LoginWithAmazonError(.couldNotInitializeAccount, file: #file, function: #function, line: #line)
					}
					return acct
			}
		}
		let headers = HTTPHeaders.init([("x-amz-access-token", token)])
		return client.get(LWASites.users, headers: headers)
			.flatMap(to: AmazonAccount.self) { res in
				switch res.http.status.code {
				case 200:
					do {
						return try res.content.decode(LWACustomerProfileResponse.self)
							.flatMap(to: AmazonAccount?.self) { scope in
								logger.info("Got Amazon id: \(scope.user_id)")
								return AmazonAccount.query(on: req).filter(\.id == scope.user_id).first()
							} .map (to: AmazonAccount.self) { optAcct in
								guard let acct = optAcct else {
									throw LoginWithAmazonError(.couldNotCreateAccount, file: #file, function: #function, line: #line)
								}
								return acct
						}
					} catch {
						throw LoginWithAmazonError(.couldNotInitializeAccount, file: #file, function: #function, line: #line)
					}
				default:
					if let profileRetrieveError = try? res.content.syncDecode(LWACustomerProfileResponseError.self) {
						throw LoginWithAmazonError(.couldNotRetrieveAmazonAccount(profileRetrieveError), file: #file, function: #function, line: #line)
					}
					throw LoginWithAmazonError(.couldNotInitializeAccount, file: #file, function: #function, line: #line)
				}
		}
	}
}

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

