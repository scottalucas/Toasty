import Foundation
import Vapor
import FluentSQLite

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
    
    init(name: String, username: String) {
        self.name = name
        self.username = username
    }
}


extension User: SQLiteUUIDModel {}
extension User: Content {}
extension User: Migration {}
extension User: Parameter {}
extension User {
    var alexaAccount: Children<User, AlexaAccount> {
        return children(\.toastyUserID)
    }
}
extension User {
    var fireplaces: Children<User, Fireplace> {
        return children(\.toastyUserID)
    }
}

