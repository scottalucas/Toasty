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
            print("Hit LWA login route.")
            guard
                let site = Environment.get("SITEURL"),
                let clientId = Environment.get("LWACLIENTID"),
                let clientSecret = Environment.get("LWACLIENTSECRET")
                else { throw Abort(.preconditionFailed, reason: "Failed to retrieve correct ENV variables for LWA transaction.") }
            var context = [String: String]()
            context["LWA-CLIENTID"] = clientId
            context["LWA-CLIENTSECRET"] = clientSecret
            context["SITE-URL"] = "\(site)/lwa/auth"
            context["USER-ID"] = "set user id"
            for item in context {
                print (item)
            }
            return try req.view().render("home", context)
        }
        
        func authHandler (_ req: Request) throws -> Future<String> {
            let logger = try req.make(Logger.self)
            logger.debug("Hit authHandler leaf start.")
            guard
                let site = Environment.get("SITEURL"),
                let redirectUrl = "\(site)/lwa/auth".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                let clientId = Environment.get("LWACLIENTID"),
                let clientSecret = Environment.get("LWACLIENTSECRET")
                else { throw Abort(.preconditionFailed, reason: "Failed to retrieve correct ENV variables for LWA transaction.") }
            logger.debug("Start headers: \(req.http.headers.debugDescription)")
            logger.debug("Start body: \(req.http.body.debugDescription)")
            let authResp = try req.query.decode(LWAAccessRequest.self)
            let authRequest = LWAAuthRequest.init(
                codeIn: authResp.code,
                redirectUri: redirectUrl,
                clientId: clientId,
                clientSecret: clientSecret)
            let client = try req.make(Client.self)
            logger.debug("Auth req to send: \(authRequest)")
            return client.get("https://api.amazon.com/auth/o2/token") { req in
                try req.query.encode(authRequest)
                req.http.headers = HTTPHeaders.init([("Content-Type", "application/x-www-form-urlencoded")])
                logger.debug("Post debug desc: \(req.http.debugDescription)")
                }.map (to: String.self) { res in
                    logger.debug("Hit after auth resp.")
                    logger.debug("After full desc: \(res.http.debugDescription)")
                    logger.debug("After headers: \(res.http.headers.debugDescription)")
                    logger.debug("After body: \(res.http.body.debugDescription)")
                    return "Hit LwaResponse leaf, Headers: \(res.http.headers.debugDescription)\nDescription: \(res.http.debugDescription)"
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
