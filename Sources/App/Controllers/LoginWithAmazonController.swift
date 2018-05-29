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
                else {
                    //throw one of two errors. Note we don't have the state so we can't clean up the session database.
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
            
            guard let client = try? req.make(Client.self) else { throw Abort(.failedDependency, reason: "Server error: could not create client to get amazon account.")}
            //*******************
            
            let authRequest = LWAAccessTokenRequest.init(
                codeIn: authResp.code,
                redirectUri: "\(site)\(ToastyAppRoutes.lwa.auth)",
                clientId: clientId,
                clientSecret: clientSecret)
            
            guard let lwaAccessTokenGrant:Future<LWAAccessTokenGrant> = try? getLwaAccessTokenGrant(using: authRequest, with: client) else {
                throw Abort(.notFound, reason: "Could not get access token grant.")}
            
            //*******************
            
            let amazonUserScope:Future<LWAUserScope> = try getAmazonScope(using: lwaAccessTokenGrant, on: req)
            
            let fireplaces:Future<[Fireplace]> = try getSessionFireplaces(using: authResp.state, on: req)
            
            let userAcct:Future<User> = getUser(using: amazonUserScope, on: req) //if there is an existing user account, this function also deletes all associated Alexa records
            
            let amazonAcct:Future<AmazonAccount> = flatMap(to: AmazonAccount.self, amazonUserScope, userAcct) { scope, acct in
                guard let azAcct = AmazonAccount.init(with: scope, user: acct) else {throw Abort(.notFound, reason: "Could not create Amazon account from provided user account.")}
                return azAcct.save(on: req)
            }
            
            let alexaFireplaces:Future<[AlexaFireplace]> = flatMap(to: [AlexaFireplace].self, fireplaces, amazonAcct) { fps, acct in
                var alexaFps:[Future<AlexaFireplace>] = []
                for fireplace in fps {
                    guard let newAlexaFp = AlexaFireplace.init(childOf: fireplace, associatedWith: acct)?.save(on: req) else {continue}
                    alexaFps.append( newAlexaFp )
                }
                return alexaFps.flatten(on: req)
            }
            
            return flatMap(to: View.self, userAcct, amazonAcct) { uAcct, aAcct in
                var context:[String:String] = [:]
                context["MSG"] = "User account ID: \(String(describing: uAcct.id)) Amazon account ID: \(String(describing: aAcct.id))"
                return try req.view().render("AuthUserMgmt/lwaAmazonAuthSuccess", context)
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
        //        loginWithAmazonRoutes.get("devAuth", String.parameter, use: devAuthHandler)
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
    
    func getAmazonScope (using accessCode: Future<LWAAccessTokenGrant>, on req: Request) throws -> Future<LWAUserScope> {
        guard let client = try? req.make(Client.self) else { throw Abort(.failedDependency, reason: "Could not create client to get amazon account.")}
        return accessCode
            .flatMap(to: Response.self) { code in
                let headers = HTTPHeaders.init([("x-amz-access-token", code.access_token)])
                return client.get(LWASites.users, headers: headers)
            }
            .map(to: LWAUserScope.self) { res in
                guard res.http.status.code == 200 else {
                    throw Abort(.notFound, reason: LWAUserScopeError(rawValue: res.http.status.reasonPhrase)?.desc() ?? "Unknown transaction message.")
                }
                guard let scope = try? res.content.syncDecode(LWAUserScope.self) else {throw Abort(.notFound, reason: "Could not decode user scope from Amazon.")}
                return scope
        }
    }
    
    func getAmazonAccount(using scope: Future<LWAUserScope>, on req: Request) -> Future<AmazonAccount?> {
        return scope.flatMap(to: AmazonAccount?.self) { scope in
            return try AmazonAccount.query(on: req).filter(\.amazonUserId == scope.user_id).first()
        }
    }
    
    func getUser (using scope: Future<LWAUserScope>, on req: Request) -> Future<User> {
        return scope.flatMap(to: AmazonAccount?.self) { scope in
            return try AmazonAccount.query(on: req).filter(\.amazonUserId == scope.user_id).first()
            }
            .flatMap (to: User.self) { optAcct in
                guard let acct = optAcct else {
                    return User.init().save(on: req)
                }
                let user = try acct.user.get(on: req)
                let _ = self.deleteAmazonAccounts(for: user, context: req)
                return user
        }
    }
    
    func deleteAmazonAccounts (for associatedUser: Future<User>, context req: Request) -> Future<String> {
        return associatedUser.flatMap (to: [AmazonAccount].self) { user in
            return try user.amazonAccount.query(on: req).all() }
            .map (to: Void.self) { accounts in
                for account in accounts {
                    let _ = try account.fireplaces.query(on: req).delete()
                    let _ = account.delete(on: req)
                }
                return
            }
            .transform(to: "Complete")
    }
}
