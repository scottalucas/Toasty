import Vapor
import Fluent
//import CNIOHTTPParser

struct LoginWithAmazonController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let loginWithAmazonRoutes = router.grouped("lwa")

        func helloHandler (_ req: Request) throws -> String {
            let logger = try req.make(Logger.self)
            logger.debug("Hit LWA base route.")
            return "Hello! You got LWA!"
        }
        
        func loginHandler (_ req: Request) throws -> Future<View> {
            let logger = try req.make(Logger.self)
            logger.debug("Hit LWA login route.")
            guard
                let site = Environment.get("SITEURL")
                else { throw Abort(.preconditionFailed, reason: "Server Error: Failed to retrieve correct ENV variables for LWA transaction.") }
            var context = [String: String]()
            context["SITEURL"] = "\(site)\(ToastyAppRoutes.lwa.auth)"
            context["PROFILE"] = "profile"
            context["INTERACTIVE"] = "always"
            context["RESPONSETYPE"] = "code"
            context["STATE"] = "some user id"
            return try req.view().render("lwaLogin", context)
        }
        
        func authHandler (_ req: Request) throws -> Future<String> {
            let logger = try req.make(Logger.self)
            logger.debug("Hit authHandler leaf start.\n\n")
            guard
                let site = Environment.get("SITEURL"),
                let clientId = Environment.get("LWACLIENTID"),
                let clientSecret = Environment.get("LWACLIENTSECRET")
                else { throw Abort(.preconditionFailed, reason: "Server error: failed to retrieve correct ENV variables for LWA transaction.") }
            logger.debug("Start desc: \(req.http.debugDescription)")
            let authResp = try req.query.decode(LWAAccessTokenRequest.self)
            let authRequest = LWAAccessTokenRequest.init(
                codeIn: authResp.code,
                redirectUri: "\(site)/lwa/auth",
                clientId: clientId,
                clientSecret: clientSecret)
            let client = try req.make(Client.self)
            logger.debug("Auth req to send: \(authRequest)")
            return client.post("https://api.amazon.com/auth/o2/token")
                { req in
                    req.http.contentType = .urlEncodedForm
                    try req.content.encode(authRequest, as: .urlEncodedForm)
                    logger.debug("Request sent to LWA server:\n \(req.http.debugDescription)\n\n")
                }
                .flatMap (to: LWAAccessTokenGrant.self) { res in
                    return try res.content.decode(LWAAccessTokenGrant.self)
                }
                .flatMap (to: Response.self) { tokenStruct in
                    let token = tokenStruct.access_token
                    let client = try req.make(Client.self)
                    let headers = HTTPHeaders.init([("x-amz-access-token", token)])
                    return client.post("api.amazon.com/user/profile", headers: headers)
                }
                .flatMap (to: LWAUserScope.self) { res in
                    return try res.content.decode(LWAUserScope.self)
                }
                .map (to: String.self) { userStruct in
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
        
        //        func newAccountHandler (_ req: Request, accessToken: LWAAccessToken) -> String {
        //            let logger = PrintLogger()
        //            let body = req.http.body.debugDescription
        //            logger.info("HTTP body in new account linker: \(body)")
        //            return body
        //        }
        
        loginWithAmazonRoutes.get("hello", use: helloHandler)
        loginWithAmazonRoutes.get("auth", use: authHandler)
        loginWithAmazonRoutes.post("access", use: accessHandler)
        loginWithAmazonRoutes.get("login", use: loginHandler)
    }
    
}

struct AccessResponse: Parameter {
    
    var access_token: String
    var token_type: String?
    var expires_in: Int?
    var refresh_token: String?
    
    init (id: String) {
        access_token = id
    }
    
    static func resolveParameter(_ parameter: String, on container: Container) throws -> AccessResponse {
        return AccessResponse(id: parameter)
    }
}
