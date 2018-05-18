import Vapor
import Fluent
import CNIOHTTPParser

struct LoginWithAmazonController: RouteCollection {
//    let logger = PrintLogger()

    func boot(router: Router) throws {
    
        let loginWithAmazonRoutes = router.grouped("lwa")
        
        func helloHandler (_ req: Request) -> String {
            logger.info("Hit LWA base route.")
            print("print Hit LWA base route.")
            return "Hello! You got LWA!"
        }
        
        func loginHandler (_ req: Request) throws -> Future<View> {
            logger.info("Hit LWA login route.")
            var context = [String: String]()
            context["LWA-CLIENTID"] = Environment.get("LWACLIENTID") ?? "Client ID not found."
            context["LWA-CLIENTSECRET"] = Environment.get("LWACLIENTSECRET") ?? "Client secret not found"
            context["SITE-URL"] = Environment.get("SITEURL") ?? "Site url not found"
            return try req.view().render("home", context)
        }
        
        func authHandler (_ req: Request) throws -> Future<String> {
            logger.info("Hit authHandler leaf start.")
            let authResp = try req.query.decode(LWAAccessAuth.self)
            let client = try req.make(Client.self)
            return client.post("https://api.amazon.com/auth/o2/token") { post in
                try post.content.encode(LWAAccessRequest(code: authResp.code, redirect_uri: "\(Environment.get("SITEURL") ?? "url not available")/lwa/access", client_id: "\(Environment.get("LWACLIENTID") ?? "Client id not available")", client_secret: "\(Environment.get("LWACLIENTSECRET") ?? "Client secret not available")"))
            }.map (to: String.self) { res in
                logger.info("Hit after auth resp.")
                logger.info("Headers: \(res.http.headers.debugDescription)")
                logger.info("Body: \(res.http.body.debugDescription)")
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
        
        func newAccountHandler (_ req: Request, accessToken: LWAAccessToken) -> String {
            let body = req.http.body.debugDescription
            logger.info("HTTP body in new account linker: \(body)")
            return body
        }
        //        }
        
        //        func createHandler(_ req: Request, acronym: Acronym) throws -> Future<Acronym> {
        //            return acronym.save(on: req)
        //        }
        //        //        func createHandler(_ req: Request) throws -> Future<Acronym> {
        //        //            return try req.content
        //        //                .decode(Acronym.self)
        //        //                .flatMap(to: Acronym.self) { acronym in
        //        //                    return acronym.save(on: req)
        //        //            }
        //        //        }
        //
        //        func getHandler(_ req: Request) throws -> Future<Acronym> {
        //            return try req.parameters.next(Acronym.self)
        //        }
        //
        //        func updateHandler(_ req: Request) throws -> Future<Acronym> {
        //            return try flatMap(to: Acronym.self,
        //                               req.parameters.next(Acronym.self),
        //                               req.content.decode(Acronym.self)) {
        //                                acronym, updatedAcronym in
        //                                acronym.short = updatedAcronym.short
        //                                acronym.long = updatedAcronym.long
        //                                acronym.userID = updatedAcronym.userID
        //                                return acronym.save(on: req)
        //            }
        //        }
        //
        //        func deleteHandler(_ req: Request)
        //            throws -> Future<HTTPStatus> {
        //
        //                return try req.parameters
        //                    .next(Acronym.self)
        //                    .delete(on: req)
        //                    .transform(to: HTTPStatus.noContent)
        //        }
        //
        //        func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        //            guard let searchTerm = req.query[String.self,
        //                                             at: "term"] else {
        //                                                throw Abort(.badRequest)
        //            }
        //            return try Acronym.query(on: req).group(.or) { or in
        //                try or.filter(\.short == searchTerm)
        //                try or.filter(\.long == searchTerm)
        //                }.all()
        //        }
        //
        //        func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
        //            return Acronym.query(on: req).first().map(to: Acronym.self) {
        //                acronym in
        //                guard let acronym = acronym else {
        //                    throw Abort(.notFound)
        //                }
        //                return acronym
        //            }
        //        }
        //
        //        func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
        //            return try Acronym.query(on: req)
        //                .sort(\.short, .ascending)
        //                .all()
        //        }
        //
        //        func getUserHandler(_ req: Request) throws -> Future<User> {
        //            return try req.parameters.next(Acronym.self)
        //                .flatMap(to: User.self) { acronym in
        //                    try acronym.user.get(on: req)
        //            }
        //        }
        
        loginWithAmazonRoutes.get("auth", use: authHandler)
        loginWithAmazonRoutes.get("access", use: accessHandler)
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


