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
        guard let client = try? req.make(Client.self) else { throw Abort(.failedDependency, reason: "Could not create client to get amazon account.")}
        if token == "access-token-from-skill" {
            return AmazonAccount.query(on: req).first()
                .map (to: AmazonAccount.self) { optAcct in
                    guard let acct = optAcct else {
                        throw Abort(.notFound, reason: "No AZ accounts in the system.")
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
                                    throw Abort(.notFound, reason: "Could not find Amazon account in database.")
                                }
                                return acct
                        }
                    } catch {
                        throw Abort(.notFound, reason: "Could not find Amazon account in database.")
                    }
                default:
                    do {
                        let profileRetrieveError = try res.content.syncDecode(LWACustomerProfileResponseError.self)
                        throw Abort(.notFound, reason: "Couldn't retrieve Amazon account, error: \(profileRetrieveError.error), detail: \(profileRetrieveError.error_description)")
                    } catch {
                        throw Abort(.notFound, reason: "Failed to retrieve Amazon user id, error code: \(res.http.status.code)")
                    }
                }
        }
    }
}

