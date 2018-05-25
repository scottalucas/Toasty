import Foundation
import Vapor
import FluentPostgreSQL

final class User: Codable, Model {
    var id: UUID?
    var name: String?
    var username: String?
    
    init() {
        name = "Anonymous"
        username = "anonymous"
    }
    
    init(name: String, username: String) {
        self.name = name
        self.username = username
    }
}


extension User: PostgreSQLUUIDModel {}
extension User: Content {}
extension User: Migration {}
extension User: Parameter {}
extension User {
    var amazonAccounts: Children<User, AmazonAccount> {
        return children(\.userId)
    }
    var fireplaces: Children<User, Fireplace> {
        return children(\.userId)
    }
}
extension User {

}

