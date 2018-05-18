import Vapor
import Fluent
import CNIOHTTPParser

struct LoginWithAmazonController: RouteCollection {
    let logger = PrintLogger()

    func boot(router: Router) throws {
    
        let loginWithAmazonRoutes = router.grouped("lwa")
        
        func helloHandler (_ req: Request) -> String {
            let logger = PrintLogger()
            logger.info("Hit LWA base route.")
            return "Hello! You got LWA!"
        }
        
        func loginHandler (_ req: Request) throws -> Future<View> {
            let logger = PrintLogger()
            logger.info("Hit LWA login route.")
            var context = [String: String]()
            context["LWA-CLIENTID"] = Environment.get("LWACLIENTID") ?? "Client ID not found."
            context["LWA-CLIENTSECRET"] = Environment.get("LWACLIENTSECRET") ?? "Client secret not found"
            context["SITE-URL"] = Environment.get("SITEURL") ?? "Site url not found"
            return try req.view().render("home", context)
        }
        
        func authHandler (_ req: Request) throws -> Future<String> {
            let logger = PrintLogger()
            logger.info("Hit authHandler leaf start.")
            let authResp = try req.query.decode(LWAAccessAuth.self)
            let client = try req.make(Client.self)
            return client.post("https://api.amazon.com/auth/o2/token") { post in
                try post.content.encode(LWAAccessRequest(code: authResp.code, redirect_uri: "\(Environment.get("SITEURL") ?? "url not available")/lwa/access", client_id: "\(Environment.get("LWACLIENTID") ?? "Client id not available")", client_secret: "\(Environment.get("LWACLIENTSECRET") ?? "Client secret not available")"))
            }.map (to: String.self) { res in
                self.logger.info("Hit after auth resp.")
                self.logger.info("Headers: \(res.http.headers.debugDescription)")
                self.logger.info("Body: \(res.http.body.debugDescription)")
                return "Hit LwaResponse leaf, Headers: \(res.http.headers.debugDescription)\nDescription: \(res.http.description)\nStatus: \(res.http.status)\nBody: \(res.http.body.debugDescription)"
            }
        }
        
        func accessHandler (_ req: Request) throws -> String {
            let logger = PrintLogger()
            let retText = "post test route"
            logger.info("Hit post test route.")
            logger.info("Headers: \(req.http.headers.debugDescription)")
            logger.info("Method: \(req.http.method)")
            logger.info("URL: \(req.http.urlString)")
            return retText
        }
        
        func newAccountHandler (_ req: Request, accessToken: LWAAccessToken) -> String {
            let logger = PrintLogger()
            let body = req.http.body.debugDescription
            logger.info("HTTP body in new account linker: \(body)")
            return body
        }

        loginWithAmazonRoutes.get("hello", use: helloHandler)
        loginWithAmazonRoutes.get("auth", use: authHandler)
        loginWithAmazonRoutes.post("access", use: accessHandler)
        loginWithAmazonRoutes.get("login", use: loginHandler)

        //        loginWithAmazonRoutes.post(LWAAccessToken.self, at: "NewAccount", use: newAccountHandler)
//        loginWithAmazonRoutes.post("NewAccount", use: newAccountHandler)

        //        acronymsRoutes.get(Acronym.parameter, use: getHandler)
        //        acronymsRoutes.put(Acronym.parameter, use: updateHandler)
        //        acronymsRoutes.delete(Acronym.parameter, use: deleteHandler)
        //        acronymsRoutes.get("search", use: searchHandler)
        //        acronymsRoutes.get("first", use: getFirstHandler)
        //        acronymsRoutes.get("sorted", use: sortedHandler)
        //        acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler)
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


