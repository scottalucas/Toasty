//
//  LoginWithAmazon.swift
//  App
//
//  Created by Scott Lucas on 5/14/18.
//

import Foundation
import Vapor
import FluentPostgreSQL

final class AmazonAccount: Codable {
	private var amazonUserId: String
	var email: String?
	var name: String?
	var postalCode: String?
//	var userId: User.ID //foreign key to main user account
	
	init? (with lwaScope: LWACustomerProfileResponse) {
//		guard let myId = user.id else {return nil}
		amazonUserId = lwaScope.user_id
		email = lwaScope.email
		name = lwaScope.name
		postalCode = lwaScope.postal_code
//		self.userId = myId
	}
	
	init (_ aId: String) {
		amazonUserId = aId
	}
	
	func didCreate(on connection: PostgreSQLConnection) throws -> EventLoopFuture<AmazonAccount> {
		logger.info("Created new Alexa Account\n\tid: \(amazonUserId)")
		return Future.map(on: connection) {self}
	}
	
	func willUpdate(on connection: PostgreSQLConnection) throws -> EventLoopFuture<AmazonAccount> {
		logger.info("Ready to update Alexa Account\n\tid: \(amazonUserId)")
		return Future.map(on: connection) {self}
	}
	
	func didUpdate(on connection: PostgreSQLConnection) throws -> EventLoopFuture<AmazonAccount> {
		logger.info("Updated Alexa Account.")
		return Future.map(on: connection) {self}
	}
}

extension AmazonAccount: PostgreSQLStringModel {
	typealias Database = PostgreSQLDatabase

	var id: String? {
		get {
			return amazonUserId
		}
		set(newValue) {
			guard let new = newValue else {return}
			amazonUserId = new
		}
	}
	
	typealias ID = String
	static let idKey: IDKey = \.id
}

//extension AmazonAccount: PostgreSQLModel {}
extension AmazonAccount: Content {}
extension AmazonAccount: Migration {}
extension AmazonAccount: Parameter {}

extension AmazonAccount { //interact with Login with Amazon to get user id.
	static func getAmazonAccount (usingToken token: String, on req: Request) -> Future<Result<AmazonAccount, LoginWithAmazonError>> {
		let logger = try? req.make(Logger.self)
		
		guard let client = try? req.make(Client.self) else {
			return req.future(.failure(LoginWithAmazonError(.serverError, file: #file, function: #function, line: #line))) }
		
		if token == "test" { //for testing on
			return AmazonAccount.query(on: req).first()
				.map(to: Result<AmazonAccount, LoginWithAmazonError>.self) { optAcct in
					guard let acct = optAcct else { return .failure(LoginWithAmazonError(.accountNotFound, file: #file, function: #function, line: #line)) }
					return .success(acct)
			}
		}

		let headers = HTTPHeaders.init([("x-amz-access-token", token)])
		return client.get(LWASites.users, headers: headers)
			.flatMap(to: Result<AmazonAccount, LoginWithAmazonError>.self) { res in
				switch res.http.status.code {
				case 200:
					do {
						return try res.content.decode(LWACustomerProfileResponse.self)
							.flatMap(to: AmazonAccount?.self) { profile in
								logger?.info("Got Amazon id: \(profile.user_id)")
								return AmazonAccount.find(profile.user_id, on: req)
							}
							.map(to: Result<AmazonAccount, LoginWithAmazonError>.self) {optAcct in
								guard let acct = optAcct else { return .failure(LoginWithAmazonError(.accountNotFound, file: #file, function: #function, line: #line))}
								return .success(acct)
						}
					} catch {
						logger?.info("Failed to decode Amazon id. Response: \(res.debugDescription) File: \(#file) Function: \(#function) Line: \(#line)")
						return req.future(.failure(LoginWithAmazonError(.couldNotDecode, file: #file, function: #function, line: #line)))
					}
				default:
					logger?.info("Request to LWA returned error code. Response: \(res.debugDescription) File: \(#file) Function: \(#function) Line: \(#line)")
					return req.future(.failure(LoginWithAmazonError(.accountNotFound, file: #file, function: #function, line: #line)))
				}
		}
	}
}

struct LWACustomerProfileResponse:Content {
	var user_id: String
	var email: String?
	var name: String?
	var postal_code: String?
}

struct LWACustomerProfileResponseError: Content { //MARK
	let error: String
	let error_description: String
	let request_id: String?
	
	init () {
		error = ""
		error_description = ""
		request_id = nil
	}
}

struct LWAUserScopeError : Decodable, Error { //MARK
	var error: String?
	var error_description: String?
	var request_id: String?
	var msg: Category?
	
	enum Category: String {
		case success = "Success"
		case invalidRequest = "invalid_request"
		case invalidToken = "invalid_token"
		case insufficientScope = "insufficient_scope"
		case serverError = "ServerError"
	}
	
	var message: String {
		switch msg {
		case .success?:
			return "The request was successful."
		case .invalidRequest?:
			return "The request is missing a required parameter or otherwise malformed."
		case .invalidToken?:
			return "The access token provided is expired, revoked, malformed, or invalid for other reasons."
		case .insufficientScope?:
			return "The access token provided does not have access to the required scope."
		case .serverError?:
			return "The Amazon server encountered a runtime error."
		case .none:
			return "Error"
		}
	}
	
	enum CodingKeys: String, CodingKey {
		case error, error_description, request_id
	}
	
	mutating func setMessage (message: String) throws {
		guard msg == Category(rawValue: message) else {
			throw LoginWithAmazonError(.lwaError , file: #file, function: #function, line: #line)
		}
	}
}

struct LWAAuthTokenResponse: Content {
	var accessCode:String //access code
	var placeholderUserId:String
	
	enum CodingKeys : String, CodingKey {
		case accessCode = "code"
		case placeholderUserId = "state"
	}
}

struct LWAAuthTokenResponseError: Content { //MARK
	var error:String
	var error_description:String
	var error_uri:String?
	var state:String?
}

struct LWAAccessTokenRequest: Content {
	var grant_type: String
	var code: String
	var redirect_uri: String
	var client_id: String
	var client_secret: String
	
	init (codeIn: String, redirectUri: String, clientId: String, clientSecret: String) {
		grant_type = "authorization_code"
		code = codeIn
		redirect_uri = redirectUri
		client_id = clientId
		client_secret = clientSecret
	}
}

struct LWAAccessTokenGrant: Content {
	var access_token: String
	var token_type: String
	var expires_in: Int
	var refresh_token: String
}

struct LWAAccessTokenGrantError: Content { //MARK
	var error:String
	var error_description: String
	var error_uri: String?
}

struct LWASites {
	static let mock:Bool = false
	static let tokens:String = mock ? "http://toastylwa.mocklab.io/auth/o2/token" : "https://api.amazon.com/auth/o2/token"
	static let users:String = mock ? "http://toastylwa.mocklab.io/user/profile" : "https://api.amazon.com/user/profile"
}

struct LWATokenRequestConfig {
	static let profile:String = "profile:user_id"
	static let responseType:String = "code"
}

struct LoginPageSpecification: Content {
	var userId: String
	var interactionMode: String
	var pageString:String
	
	init(_ id: String, mode: String) {
		userId = id
		interactionMode = mode
		pageString = "\(ToastyServerRoutes.Lwa.root)\(ToastyServerRoutes.Lwa.loginPage)/\(userId)/\(interactionMode)"
	}
}

enum LWAInteractionMode: String {
	case always, auto, never
}


