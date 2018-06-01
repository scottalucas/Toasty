import Vapor
import Fluent
import FluentPostgreSQL
//import CNIOHTTPParser

struct LoginWithAmazonController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let loginWithAmazonRoutes = router.grouped(ToastyAppRoutes.lwa.lwaRoot)
        
        func helloHandler (_ req: Request) throws -> String {
            logger.debug("Hit LWA base route.")
            return "Hello! You got LWA!"
        }
        
        func loginHandler (_ req: Request) throws -> Future<View> {
            let logger = try req.make(Logger.self)
            logger.info("Login handler hit with \(req.debugDescription)")
            var context = [String: String]()
            guard
                let site = Environment.get(ENVVariables.siteUrl),
                let clientId = Environment.get(ENVVariables.lwaClientId)
                else { throw Abort(.preconditionFailed, reason: "Server Error: Failed to retrieve correct ENV variables for LWA transaction.") }
            guard
                let fireplaces = try? req.content.syncDecode([Fireplace].self),
                fireplaces.count > 0
                else {
                    context["MSG"] = "No fireplaces found or malformed JSON in request, please discover fireplaces first."
                    return try req.view().render("noFireplaces", context)
            }
            return User(name: "Placeholder", username: "Placeholder") .save(on: req)
                .flatMap(to: [Fireplace].self) { usr in
                    guard let usrId = usr.id else { throw Abort(.notFound, reason: "Failed to create placeholder user account")}
                    context["SITEURL"] = "\(site)\(ToastyAppRoutes.lwa.auth)"
                    context["PROFILE"] = LWATokenRequestConfig.profile
                    context["INTERACTIVE"] = LWATokenRequestConfig.interactive
                    context["RESPONSETYPE"] = LWATokenRequestConfig.responseType
                    context["STATE"] = usrId.uuidString
                    context["LWACLIENTID"] = clientId
                    var saveResults: [Future<Fireplace>] = []
                    for fireplace in fireplaces {
                        saveResults.append(Fireplace.init(power: fireplace.powerSource, imp: fireplace.controlUrl, user: usrId, friendly: fireplace.friendlyName).save(on: req))
                    }
                    return saveResults.flatten(on: req)
                } .flatMap (to: View.self) { fps in
                    return try req.view().render("AuthUserMgmt/lwaLogin", context)
            }
        }
        
        func authHandler (_ req: Request) throws -> Future<View> {
            let logger = try req.make(Logger.self)
            logger.info(req.debugDescription)
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
            
            let authRequest = LWAAccessTokenRequest.init(
                codeIn: authResp.accessCode,
                redirectUri: "\(site)\(ToastyAppRoutes.lwa.auth)",
                clientId: clientId,
                clientSecret: clientSecret)
            
            guard let lwaAccessTokenGrant:Future<LWAAccessTokenGrant> = try? getLwaAccessTokenGrant(using: authRequest, with: client) else {
                throw Abort(.notFound, reason: "Could not get access token grant.")}
            
            let placeholderUserAccount:Future<User?> = getPlaceholderUserAccount(placeholderUserId: authResp.placeholderUserId, context: req)
            
            let discoveredFireplaces:Future<[Fireplace]> = try getSessionFireplaces(using: placeholderUserAccount, on: req)
            
            let amazonUserScope:Future<LWAUserScope> = try getAmazonScope(using: lwaAccessTokenGrant, on: req)
            
            let userAcct:Future<User> = flatMap(to: User.self, amazonUserScope, placeholderUserAccount) { scope, placeholderUser in
                do {
                    return try AmazonAccount.query(on: req).filter(\.amazonUserId == scope.user_id).first()
                        .flatMap (to: User.self) { optAzAcct in
                            if let azAcct = optAzAcct {
                                return try azAcct.user.get(on: req)
                            } else if let placeholderUsr = placeholderUser {
                                placeholderUsr.setName("Anonymous")
                                placeholderUsr.setUsername("Anonymous")
                                return placeholderUsr.save(on: req)
                            } else {
                                return User.init(name: "Anonymous", username: "Anonymous").save(on: req)
                            }
                    }
                } catch {
                    return User.init(name: "Anonymous", username: "Anonymous").save(on: req)
                }
            }
            
            let amazonAcct:Future<AmazonAccount> = flatMap(to: AmazonAccount.self, amazonUserScope, userAcct) { scope, usrAcct in
                guard usrAcct.id != nil else { throw Abort(.notFound, reason: "Could not create Amazon account, malformed user account.")}
                do {
                    return try AmazonAccount.query(on: req).filter(\.amazonUserId == scope.user_id).first()
                        .flatMap(to: AmazonAccount.self) { optAzAcct in
                            if let azAcct = optAzAcct { //found an existing amazon account that matches the one returned, so update it
                                azAcct.email = scope.email
                                azAcct.name = scope.name
                                azAcct.postalCode = scope.postal_code
                                azAcct.userId = usrAcct.id!
                                return azAcct.save(on: req)
                            } else { //need to make a new Amazon account
                                return AmazonAccount.init(with: scope, user: usrAcct)!.save(on: req)
                            }
                    }
                } catch {
                    return AmazonAccount.init(with: scope, user: usrAcct)!.save(on: req)
                }
            }
            
            let installMsg = installFireplaces(userAccount: userAcct, amazonAccount: amazonAcct, discoveredFps: discoveredFireplaces, context: req)
            
            return flatMap(to: View.self, userAcct, amazonAcct, placeholderUserAccount, installMsg) { uAcct, aAcct, dAcct, msg in
                var deleteMessage:Future<String>
                if let garbageAcct = dAcct, garbageAcct.name == "Placeholder" {
                    deleteMessage = garbageAcct.delete(on: req).transform(to: "Deleted one placeholder account")
                } else {
                    deleteMessage = Future.map(on: req) {"Placeholder account reused."}
                }
                var context:[String:String] = [:]
                return deleteMessage.flatMap (to: View.self) { dMsg in
                    context["MSG"] = "Created user account ID: \(String(describing: uAcct.id)) Amazon account ID: \(String(describing: aAcct.amazonUserId))\n\n\(msg)\n\n\(dMsg)"
                    return try req.view().render("AuthUserMgmt/lwaAmazonAuthSuccess", context)
                }
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
        loginWithAmazonRoutes.post("login", use: loginHandler)
    }
    //*******************************************************************************
    //help functions, not route responders
    //*******************************************************************************

    func getLwaAccessTokenGrant (using lwaAccessReq:LWAAccessTokenRequest, with client: Client) throws -> Future<LWAAccessTokenGrant> {
        
        return client.post(LWASites.tokens, beforeSend: { newPost in
            logger.info("Asking for token from: \(LWASites.tokens)")
            newPost.http.contentType = .urlEncodedForm
            do { try newPost.content.encode(lwaAccessReq, as: .urlEncodedForm)
                logger.info("Sending token request: \(newPost.debugDescription)")
            } catch {
                logger.info("Token request failed: \(newPost.debugDescription)")
                throw Abort(.badRequest, reason: "Could not encode authorization request.")
            }
        })
            .map (to: LWAAccessTokenGrant.self) { res in
                let logger = try res.make(Logger.self)
                do { logger.info("Token grant response: \(res.debugDescription)")
                    return try res.content.syncDecode(LWAAccessTokenGrant.self) }
                catch {
                    logger.info("Access token grant failed.")
                    if let err = try? res.content.syncDecode(LWAAccessTokenGrantError.self) {
                        throw Abort(.unauthorized, reason: err.error_description) }
                    else {
                        throw Abort(.notFound, reason: "Unknown error")
                    }
                }
        }
    }
    
    func getSessionFireplaces (using placeholderAcct: Future<User?>, on req: Request) throws -> Future<[Fireplace]> {
        return placeholderAcct.flatMap (to: [Fireplace].self) { optAcct in
            guard let
                acct = optAcct
                else { throw Abort(.notFound, reason: "No fireplaces found, please try again after discovering fireplaces.")
            }
            return try acct.fireplaces.query(on: req).all()
        }
    }
    
    func getAmazonScope (using accessCode: Future<LWAAccessTokenGrant>, on req: Request) throws -> Future<LWAUserScope> {
        guard let client = try? req.make(Client.self) else { throw Abort(.failedDependency, reason: "Could not create client to get amazon account.")}
        return accessCode
            .flatMap(to: Response.self) { code in
                let headers = HTTPHeaders.init([("x-amz-access-token", code.access_token)])
                logger.info("Requesting user scope from: \(LWASites.users)")
                return client.get(LWASites.users, headers: headers)
            }
            .map(to: LWAUserScope.self) { res in
                logger.info("Got user scope from: \(res.debugDescription)")
                guard res.http.status.code == 200 else {
                    throw Abort(.notFound, reason: LWAUserScopeError(rawValue: res.http.status.reasonPhrase)?.desc() ?? "Unknown transaction message.")
                }
                guard let scope = try? res.content.syncDecode(LWAUserScope.self) else {throw Abort(.notFound, reason: "Could not decode user scope from Amazon.")}
                return scope
        }
    }
    
    func getPlaceholderUserAccount (placeholderUserId: String, context req: Request) -> Future<User?> {
        guard let placeholderUuid = UUID.init(placeholderUserId) else { return Future.map(on: req) {nil} }
        do {
            return try User.query(on: req).filter(\.id == placeholderUuid).first()
        } catch {
            return Future.map(on: req) {nil}
        }
    }
    
    func getUser (basedOn scope: Future<LWAUserScope>, orCreateFrom: Future<User?>, on req: Request) -> Future<User> {
        return flatMap(to: User.self, scope, orCreateFrom) { scope, placeholderUser in
            do {
                return try AmazonAccount.query(on: req).filter(\.amazonUserId == scope.user_id).first()
                    .flatMap (to: User.self) { optAzAcct in
                        if let azAcct = optAzAcct {
                            return try azAcct.user.get(on: req)
                        } else if let placeholderUsr = placeholderUser {
                            placeholderUsr.setName("Anonymous")
                            placeholderUsr.setUsername("Anonymous")
                            return placeholderUsr.update(on: req)
                        } else {
                            return User.init(name: "Anonymous", username: "Anonymous").save(on: req)
                        }
                }
            } catch {
                return User.init(name: "Anonymous", username: "Anonymous").save(on: req)
            }
        }
    }
    
    func installFireplaces(userAccount: Future<User>, amazonAccount: Future<AmazonAccount>, discoveredFps: Future<[Fireplace]>, context req: Request) -> Future<String> {
        return flatMap(to: String.self, userAccount, amazonAccount, discoveredFps) { usrAcct, azAcct, candidateFps in
            guard usrAcct.id != nil, azAcct.id != nil else {throw Abort(.notFound, reason: "Malformed user or Amazon account object during fireplace installation.")}
            var savedAzFpTracker:[Future<AlexaFireplace>] = Array ()
            var updatedFpTracker:[Future<Fireplace>] = Array ()
            for candidateFp in candidateFps {
                let finalFp:Future<Fireplace> = try Fireplace.query(on: req).filter(\.controlUrl == candidateFp.controlUrl).filter(\.id != candidateFp.id).first() //check to see if we laready have an FP, based on the IMP url
                    .flatMap(to: Fireplace.self) { optExistingFp in
                        if let existingFp = optExistingFp { //there's an existing FP
                            existingFp.friendlyName = candidateFp.friendlyName
                            existingFp.powerSource = candidateFp.powerSource
                            let _ = candidateFp.delete(on: req)
                            return existingFp.update(on: req)
                        } else {
                            candidateFp.parentUserId = usrAcct.id!
                            return candidateFp.update(on: req)
                        }
                    }
                
                let finalAzFp:Future<AlexaFireplace> =
                    finalFp.flatMap(to: AlexaFireplace.self) { newFp in
                        try AlexaFireplace.query(on: req).filter(\.parentFireplaceId == newFp.id).first()
                            .flatMap (to: AlexaFireplace.self) { optAxFp in
                                let newAzFp = (optAxFp != nil) ? optAxFp! : AlexaFireplace(childOf: newFp, associatedWith: azAcct)!
                                newAzFp.parentAmazonAccountId = azAcct.id!
                                newAzFp.status = (newFp.powerSource == .battery) ? .notRegisterable : .availableForRegistration
                                return newAzFp.save(on: req)
                        }
                    }
                
                savedAzFpTracker.append(finalAzFp)
                updatedFpTracker.append(finalFp)
            }
            return flatMap(to: String.self, savedAzFpTracker.flatten(on: req), updatedFpTracker.flatten(on: req)) { savedAzFps, savedFps in
                let ret = "Updated \(savedAzFps.count) Alexa records and \(savedFps.count) fireplace records."
                return Future.map(on: req) {ret}
            }
        }
    }
}
