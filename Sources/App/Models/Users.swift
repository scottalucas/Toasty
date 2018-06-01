import Foundation
import Vapor
import FluentPostgreSQL

final class User: Codable {
    var id: UUID?
    var name: String?
    var username: String?
    
    init() {
        name = nil
        username = nil
    }
    
    init(name: String, username: String) {
        self.name = name
        self.username = username
    }
    
    func setName (_ name: String) {
        self.name = name
        return
    }
    
    func setUsername (_ userName: String) {
        self.username = userName
        return
    }
    
}


extension User: PostgreSQLUUIDModel {}
extension User: Content {}
extension User: Migration {}
extension User: Parameter {}
extension User {
    var amazonAccount: Children<User, AmazonAccount> {
        return children(\.userId)
    }
    var fireplaces: Children<User, Fireplace> {
        return children(\.parentUserId)
    }
}

