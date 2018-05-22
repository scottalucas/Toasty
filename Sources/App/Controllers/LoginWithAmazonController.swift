import Vapor
import Fluent
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
            context["SITEURL"] = "\(site)\(ToastyAppRoutes.lwa.auth)"
            context["PROFILE"] = LWATokenRequestConfig.profile
            context["INTERACTIVE"] = LWATokenRequestConfig.interactive
            context["RESPONSETYPE"] = LWATokenRequestConfig.responseType
            context["STATE"] = "some user id"
            context["LWACLIENTID"] = clientId
            return try req.view().render("lwaLogin", context)
        }
        
        func authHandler (_ req: Request) throws -> Future<String> {
            //            let logger = try req.make(Logger.self)
            guard
                let site = Environment.get(ENVVariables.siteUrl),
                let clientId = Environment.get(ENVVariables.lwaClientId),
                let clientSecret = Environment.get(ENVVariables.lwaClientSecret),
                let client = try? req.make(Client.self)
                else { throw Abort(.preconditionFailed, reason: "Server error: failed to create authentication environment.") }
            guard let authResp = try? req.query.decode(LWAAuthTokenResponse.self) else {
                if let errResp = try? req.query.decode(LWAAuthTokenResponseError.self) {
                    throw Abort(.unauthorized, reason: errResp.error_description) } else {
                    throw Abort(.notFound, reason: "Authentication failed with unknown error.")
                }
            }
            let authRequest = LWAAccessTokenRequest.init(
                codeIn: authResp.code,
                redirectUri: "\(site)\(ToastyAppRoutes.lwa.auth)",
                clientId: clientId,
                clientSecret: clientSecret)
            
            return client.post(LWASites.tokens, beforeSend: { newPost in
                newPost.http.contentType = .urlEncodedForm
                do { try newPost.content.encode(authRequest, as: .urlEncodedForm) } catch {
                    throw Abort(.badRequest, reason: "Could not encode authorization request.")
                    }
                }).map (to: LWAAccessTokenGrant.self) { res in
                    do { return try res.content.syncDecode(LWAAccessTokenGrant.self) }
                    catch {
                        do { let err = try res.content.syncDecode(LWAAccessTokenGrantError.self)
                            throw Abort(.unauthorized, reason: err.error_description) }
                        catch {
                            throw Abort(.notFound, reason: "Unknown error") }
                    }
                }.flatMap (to: LWAUserScope.self) { tokenStruct in
                    return try self.getAmazonUserIdStruct(req, accessToken: tokenStruct.access_token)
                }.map (to: String.self) { userStruct in
                        return userStruct.user_id
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
        loginWithAmazonRoutes.post("access", use: accessHandler)
        loginWithAmazonRoutes.get("login", use: loginHandler)
    }
    
    func getAmazonUserIdStruct (_ req: Request, accessToken: String) throws -> Future<LWAUserScope> {
        let client = try req.make(Client.self)
        let headers = HTTPHeaders.init([("x-amz-access-token", accessToken)])
        return client.get(LWASites.users, headers: headers)
            .map(to: LWAUserScope.self) { res in
                let respHttp = res.http
                let transactionMsg = LWAUserScopeError(rawValue: respHttp.status.reasonPhrase)?.desc() ?? "Unknown transaction message."
                guard respHttp.status.code == 200 else {throw Abort(.notFound, reason: transactionMsg)}
                do {
                    return try res.content.syncDecode(LWAUserScope.self)
                } catch {
                    throw Abort(.notFound, reason: "Could not decode returned user scope.")
                }
            }
    }
}
