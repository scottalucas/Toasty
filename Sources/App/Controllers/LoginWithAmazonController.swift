import Vapor
import Fluent
//import CNIOHTTPParser

struct LoginWithAmazonController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let loginWithAmazonRoutes = router.grouped("lwa")
        
        func helloHandler (_ req: Request) -> String {
            print("Hit LWA base route.")
            return "Hello! You got LWA!"
        }
        
        func loginHandler (_ req: Request) throws -> Future<View> {
            print("Hit LWA login route.")
            var context = [String: String]()
            context["LWA-CLIENTID"] = Environment.get("LWACLIENTID") ?? "Client ID not found."
            context["LWA-CLIENTSECRET"] = Environment.get("LWACLIENTSECRET") ?? "Client secret not found"
            context["SITE-URL"] = Environment.get("SITEURL") ?? "Site url not found"
            return try req.view().render("home", context)
        }
        
        func authHandler (_ req: Request) throws -> Future<String> {
            print("Hit authHandler leaf start.")
            print("Headers: \(req.http.headers.debugDescription)")
            print("Body: \(req.http.body.debugDescription)")
            let authResp = try req.query.decode(LWAAccessRequest.self)
            let authRequest = LWAAuthRequest.init(
                codeIn: authResp.code,
                redirectUri: "\(Environment.get("SITEURL") ?? "url not available")/lwa/access",
                clientId: "\(Environment.get("LWACLIENTID") ?? "Client id not available")",
                clientSecret: "\(Environment.get("LWACLIENTSECRET") ?? "Client secret not available")")
            let client = try req.make(Client.self)
            print("Client services: \(client.container.services.description)")
            return client.post("https://api.amazon.com/auth/o2/token") { post in
                try post.query.encode(authRequest)
                }.map (to: String.self) { res in
                    print("Hit after auth resp.")
                    print("Headers: \(res.http.headers.debugDescription)")
                    print("Body: \(res.http.body.debugDescription)")
                    return "Hit LwaResponse leaf, Headers: \(res.http.headers.debugDescription)\nDescription: \(res.http.description)\nStatus: \(res.http.status)\nBody: \(res.http.body.debugDescription)"
            }
        }
        
        func accessHandler (_ req: Request) throws -> String {
            let retText = "post test route"
            logger.info("Hit post test route.")
            logger.info("Headers: \(req.http.headers.debugDescription)")
            logger.info("Method: \(req.http.method)")
            logger.info("URL: \(req.http.urlString)")
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
