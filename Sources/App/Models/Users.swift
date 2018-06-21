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
    
    init(userId: UUID) {
        id = userId
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

extension User {
    class func getAmazonAccount (usingToken token: String, on req: Request) throws -> Future<AmazonAccount> {
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
                                return try AmazonAccount.query(on: req).filter(\.amazonUserId == scope.user_id).first()
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

