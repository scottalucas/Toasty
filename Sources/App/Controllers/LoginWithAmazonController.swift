import Vapor
import Fluent
import FluentPostgreSQL
//import CNIOHTTPParser

struct LoginWithAmazonController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let loginWithAmazonRoutes = router.grouped(ToastyAppRoutes.lwa.lwaRoot)
        
        func helloHandler (_ req: Request) throws -> String {
            let logger = try req.make(Logger.self)
            logger.debug("Hit LWA base route.")
            return "Hello! You got LWA!"
        }
        
        func loginHandler (_ req: Request) throws -> Future<View> {
            guard
                let site = Environment.get(ENVVariables.siteUrl),
                let clientId = Environment.get(ENVVariables.lwaClientId)
                else { throw Abort(.preconditionFailed, reason: "Server Error: Failed to retrieve correct ENV variables for LWA transaction.") }
            var context = [String: String]()
            do {
                let fireplaces = try req.content.syncDecode([Fireplace].self)
                if fireplaces.count == 0 {
                    context["MSG"] = "No fireplaces found, please discover fireplaces first."
                    return try req.view().render("/noFireplaces", context)
                }
                var sessionData = SessionData()
                sessionData.fireplaces = fireplaces
                sessionData.expiration = Date(timeIntervalSinceNow: (30 * 60))
                //TO DO: Implement session database cleanup running every few minutes to delete stale sessions.
                return sessionData.save(on: req)
                    .flatMap(to: View.self) {sessionData in
                        guard let strId = sessionData.id else {throw Abort(.notFound, reason: "Failed to create session record.")}
                        context["SITEURL"] = "\(site)\(ToastyAppRoutes.lwa.auth)"
                        context["PROFILE"] = LWATokenRequestConfig.profile
                        context["INTERACTIVE"] = LWATokenRequestConfig.interactive
                        context["RESPONSETYPE"] = LWATokenRequestConfig.responseType
                        context["STATE"] = String(strId)
                        context["LWACLIENTID"] = clientId
                        return try req.view().render("AuthUserMgmt/lwaLogin", context)
                }
            } catch {
                throw Abort(.notFound, reason: "Couldn't decode fireplaces from request.")
            }
        }
        
        func authHandler (_ req: Request) throws -> Future<View> {
            //            let logger = try req.make(Logger.self)
            guard
                let authResp = try? req.query.decode(LWAAuthTokenResponse.self)
                else {//throw one of two errors. Note we don't have the state so we can't clean up the session database.
                    if let errResp = try? req.query.decode(LWAAuthTokenResponseError.self) {
                        throw Abort(.unauthorized, reason: errResp.error_description) }
                    else { throw Abort(.notFound, reason: "Authentication failed with unknown error.")}
            }
            guard
                let site = Environment.get(ENVVariables.siteUrl),
                let clientId = Environment.get(ENVVariables.lwaClientId),
                let clientSecret = Environment.get(ENVVariables.lwaClientSecret)
                else {
                    throw Abort(.preconditionFailed, reason: "Server error: failed to create authentication environment.") }
            
            
            
            var fireplaces:Future<[Fireplace]> = try getSessionFireplaces(using: authResp.state, on: req)
            var amazonAccount:Future<AmazonAccount> = try getAmazonAccount(using: authResp.code, on: req)
            let userAccount:Future<User> = try getUserAccount(associatedWith: amazonAccount, context: req)
            amazonAccount = flatMap(to: AmazonAccount.self, amazonAccount, userAccount) { amazonAcct, userAcct in
                amazonAcct.userId = userAcct.id
                return amazonAcct.save(on: req)
            }
            fireplaces = flatMap(to: [Fireplace].self, fireplaces, userAccount) {fps, usr in
                guard let uid = usr.id else {throw Abort(.notFound, reason: "No user id")}
                let newFps:[Future<Fireplace>] = fps.map { $0.userId = uid; return $0.save(on: req) }
                return newFps.flatten(on: req)
            }
        }
        
        func devAuthHandler (_ req: Request) throws -> (Future<View>) {
            let amazonUserId:String = try req.parameters.next()
            return try returnFutureUserAccount(with: amazonUserId, context: req)
                .flatMap (to: View.self) { user in
                    var context = [String : String]()
                    context["MSG"] = "Amazon user ID: \(amazonUserId) System ID: \(user?.id?.uuidString ?? "not found")"
                    return try req.view().render("testFeedback", context)
            }
        }
        
        func accessHandler (_ req: Request) throws -> String {
            let logger = try req.make(Logger.self)
            let retText = "post test route"
            logger.debug("Hit post test route.")
            logger.debug("Headers: \(req.http.headers.debugDescription)")
            logger.debug("Method: \(req.http.method)")
            logger.debug("URL: \(req.http.urlString)")
            return retText
        }
        
        loginWithAmazonRoutes.get("hello", use: helloHandler)
        loginWithAmazonRoutes.get("auth", use: authHandler)
        loginWithAmazonRoutes.get("devAuth", String.parameter, use: devAuthHandler)
        loginWithAmazonRoutes.post("access", use: accessHandler)
        loginWithAmazonRoutes.post("login", use: loginHandler)
    }
    
    //help functions, not route responders
    func getLwaAccessTokenGrant (using lwaAccessReq:LWAAccessTokenRequest, with client: Client) throws -> Future<LWAAccessTokenGrant> {
        return client.post(LWASites.tokens, beforeSend: { newPost in
            newPost.http.contentType = .urlEncodedForm
            do { try newPost.content.encode(lwaAccessReq, as: .urlEncodedForm) } catch {
                throw Abort(.badRequest, reason: "Could not encode authorization request.")
            }
        })
        .map (to: LWAAccessTokenGrant.self) { res in
            do { return try res.content.syncDecode(LWAAccessTokenGrant.self) }
            catch {
                do { let err = try res.content.syncDecode(LWAAccessTokenGrantError.self)
                    throw Abort(.unauthorized, reason: err.error_description) }
                catch {
                    throw Abort(.notFound, reason: "Unknown error") }
            }
        }
    }
    
    func getSessionFireplaces (using sessionId: String, on req: Request) throws -> Future<[Fireplace]> {
        return try SessionData.query(on: req).filter(\.id == Int(sessionId)).first()
            .map (to: [Fireplace].self) { data in
                guard let sessionData = data else {
                    throw Abort(.notFound, reason: "Could not retrieve fireplaces from session db.")
                }
                guard let fps = sessionData.fireplaces, fps.count > 0 else {
                    throw Abort(.notFound, reason: "Session data did not include any fireplaces.")
                }
                return fps
        }
    }
    
    func getAmazonAccount (using accessCode: String, on req: Request) throws -> Future<AmazonAccount> {
        var userScope:LWAUserScope
        guard let client = try? req.make(Client.self) else { throw Abort(.failedDependency, reason: "Could not create client to get amazon account.")}
        let headers = HTTPHeaders.init([("x-amz-access-token", accessCode)])
        return client.get(LWASites.users, headers: headers)
            .flatMap(to: AmazonAccount?.self) { res in
                guard res.http.status.code == 200 else {
                    throw Abort(.notFound, reason: LWAUserScopeError(rawValue: res.http.status.reasonPhrase)?.desc() ?? "Unknown transaction message.")
                }
                guard let scopeFromAmazon = try? res.content.syncDecode(LWAUserScope.self) else {throw Abort(.notFound, reason: "Could not decode user scope from Amazon.")}
                userScope = scopeFromAmazon
                return try AmazonAccount.query(on: req).filter(\.amazonUserId == userScope.user_id).first()
            }
            .map (to: AmazonAccount.self) { existingOptAmazonAcct in
                let candidateAmazonAcct = AmazonAccount(with: userScope, userId: nil)
                if existingOptAmazonAcct != nil {
                    candidateAmazonAcct.amazonUserId = existingOptAmazonAcct!.amazonUserId
                }
                return candidateAmazonAcct
            }
    }

//    func testGetUserAccount (associatedWith amazonAccount: Future<AmazonAccount>, context req: Request) throws -> Future<User> {
//        return amazonAccount.flatMap(to: User.self) {acct in
//            return flatMap(to: )
//        }
//    }
    
    func getUserAccount (associatedWith amazonAccount: Future<AmazonAccount>, context req: Request) throws -> Future<User>
        {
            return amazonAccount.flatMap(to: User.self) { acct in
                if acct.user == nil {return User().save(on: req)}
                return try acct.user!.get(on: req) }
            }
    }
//            .flatMap(to: User.self) { optUser, acct in
//                if let acct = optAcct {
//                    return Future.map(on: req) {return acct}
//                } else {
//                    let newUser = User(name: "Anonymous", username: "anonymous")
//                    return newUser.save(on: req)
//                }
//            }
//            .map(to: ) {
//
//            }
//                amazonAccount.userId = newUser.id
//
//                guard let acct = account else {throw Abort(.notFound, reason: "Amazon account not found in database.")}
//                if let userAcct = try? acct.user.get(on: req) { return userAcct } else {
//                    let newUser = User(name: "Anonymous", username: "anonymous")
//                    newUser.save(on: req)
//                        .map(to: User.self) {user in
//                            guard let newUserId = user.id else {throw Abort(.notFound, reason: "Ugh, this is bad.")}
//                            acct.userId = newUserId
//                            acct.save(on: req)
//                            return newUser
//                        }
//                    }
//    }
    
    func establishMandatoryAccounts (using amazonToken:String, context req: Request) -> String {
        //stuf
        return "Under development"
    }
}
