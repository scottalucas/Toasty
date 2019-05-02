//
//  TestControllers.swift
//  Toasty
//  These methods are used during interactions
//  with the user's phone app.
//
//  Created by Scott Lucas on 4/19/19.
//
import Foundation
import Vapor
import Fluent
import FluentPostgreSQL

struct AppController: RouteCollection {
	struct UserUpdatePackage: Codable {
		var userId: UUID
		var fireplaceIds: [String]
	}
	
	struct UpdateException: Codable {
		var missing: [String]
		var extra: [String]
		var available: [String]
	}
	
	func boot(router: Router) throws {
		let appRoutes = router.grouped(ToastyServerRoutes.App.root)
		
		func helloHandler (_ req: Request) -> String {
			debugPrint("Hit user controller.")
			return "Hello! You got user controller!"
		}
		
		func getUserHandler (req: Request) throws -> Future<User> {
			debugPrint("Hit get user handler.")
			guard
				let user = try? req.parameters.next(User.self)
			else { throw Abort(.notFound) }
			return user
		}
		
		/*
Adds a user and associate their fireplaces to the database. Success should return status 204 (no content). If we receive unregistered fireplaces or find fireplaces in the databased that weren't sent in the update, return status 206 (partial content) and send the extra/missing fireplaces back to the app.
		Other Errors:
			"Not found" means the user didn't send any fireplaces.
			"Bad request" means we could not decode the package sent by the app
*/
		func addUserHandler(req: Request) throws -> Future<HTTPResponse> {
			debugPrint("Hit app add handler.")
			//app sent package that couldn't be decoded
			guard
				let userUpdatePackage = try? req.content.syncDecode(UserUpdatePackage.self)
				else { throw Abort(.badRequest) }
			//app sent package without any fireplaces
			guard
				userUpdatePackage.fireplaceIds.count > 0
				else { throw Abort(.notFound) }
			
			debugPrint(userUpdatePackage)
			
			//Return the database records matching the sent fireplaces. Since fireplaces should already be registered, we aren't creating them if they don't exist in the database.
			let matchingFireplacesFromDatabase: Future<[Fireplace]> =
				Fireplace
					.query(on: req)
					.group(.or) { or in
						userUpdatePackage.fireplaceIds.forEach { or.filter(\.deviceid == $0) }
					}
					.all()
			
			//there may or may not be a user registered with this id. Return existing record or create.
			let databaseUserRecord: Future<User> =
				User
					.find(userUpdatePackage.userId, on: req)
					.flatMap(to: User.self) { optUser in
						if let usr = optUser {
							return req.future(usr)
						} else {
							return User(userId: userUpdatePackage.userId).create(on: req)
						}
			}
			
			//wait for the user and fireplaces to be retrieved from the database
			return flatMap(to: HTTPResponse.self, matchingFireplacesFromDatabase, databaseUserRecord) { databaseFireplaces, user in
				
				 //list of fireplace ids sent by app that are not registered in database. Send back to the app.
				let fireplaceIdsMissingFromDatabase =
					Array(Set(userUpdatePackage.fireplaceIds)
							.subtracting(Set(databaseFireplaces.compactMap { $0.id })))
				
				//list of fireplace ids associated with this user but not sent by the app (could be from a previous pairing event). Might consider detaching these but for now we'll just send them back to the app.
				let fireplaceIdsNotSentByApp =
					Array(Set(databaseFireplaces.compactMap { $0.id } )
							.subtracting(Set(userUpdatePackage.fireplaceIds)))
				
				//get the id for the user record from the database
				guard
					user.id != nil
					else {throw Abort(.internalServerError)}
				
				var updates: [Future<HTTPStatus>] = []
				
				//check if the fireplaces from the databased exist in the pivot for this user. If not, add them.
				for fp in databaseFireplaces {
					updates.append(
					fp.users.isAttached(user, on: req)
						.flatMap(to: HTTPResponseStatus.self) { attached in
							if !attached {
								return user.fireplaces
									.attach(fp, on: req)
									.transform(to: .created)
							} else {
								return req.future(.created)
							}
					}
				)
				}
				
				return updates
					.flatten(on: req)
					.map (to: HTTPResponse.self) { _ in
						guard
							fireplaceIdsMissingFromDatabase.count == 0,
							fireplaceIdsNotSentByApp.count == 0
							else {
								let encoder = JSONEncoder()
								let d = try! encoder.encode(UpdateException(missing: fireplaceIdsMissingFromDatabase, extra: fireplaceIdsNotSentByApp, available: databaseFireplaces.compactMap { $0.id } ))
								var res = HTTPResponse(status: .partialContent)
								res.body = HTTPBody(data: d)
								return res
						}
						return HTTPResponse(status: .noContent)
				}
			}
		}
		
		func  deleteUserHandler(req: Request) throws -> Future<HTTPResponse> {
			guard let user = try? req.parameters.next(User.self) else {return req.future(HTTPResponse(status: .notFound))}
			return user
				.delete(on: req)
				.transform(to: HTTPResponse(status: .noContent))
			
		}
		
		appRoutes.get(use: helloHandler)
		appRoutes.get(ToastyServerRoutes.App.user, User.parameter, use: getUserHandler)
		appRoutes.post(ToastyServerRoutes.App.user, use: addUserHandler) //post body contains UserUpdatePackage
		appRoutes.delete(ToastyServerRoutes.App.user, User.parameter, use: deleteUserHandler)
	}
}

struct AlexaAppController: RouteCollection {
	
	struct AlexaUser: Content {
		var userId: UUID
		var amazonId: String?
	}
	
	func boot(router: Router) throws {
		let appRoutes = router.grouped(ToastyServerRoutes.App.root, ToastyServerRoutes.App.Alexa.root)
		
		func helloHandler (_ req: Request) -> String {
			debugPrint("Hit Alexa app controller.")
			return "Hello! You got Alexa App controller!"
		}
		
		func getAccountHandler (req: Request) throws -> Future<AmazonAccount> {
			debugPrint("Hit get Alexa user handler.")
			guard
				let acct = try? req.parameters.next(AmazonAccount.self)
				else { throw Abort(.badRequest) }
			return acct
		}
		
		func addAccountHandler(req: Request) throws -> Future<HTTPResponse> {
			debugPrint("Hit alexa account add handler.")
			guard let amazonAccount = try? req.content.syncDecode(AmazonAccount.self)
				else { throw Abort(.badRequest) }
			debugPrint(amazonAccount)
			return amazonAccount.create(orUpdate: true, on: req)
				.transform(to: HTTPResponse(status: .noContent))
		}
		
		func  deleteAccountHandler(req: Request) throws -> Future<HTTPResponse> {
			guard let acct = try? req.parameters.next(AmazonAccount.self) else {throw Abort(.notFound)}
			return acct.delete(on: req)
				.transform(to: HTTPResponse(status: .ok))
		}
		
		func addFireplacesHandler(req: Request) throws -> HTTPResponse {
			debugPrint("Hit add fireplace handler.")
			return HTTPResponse(status: .ok)
		}
		
		func deleteFireplacesHandler(req: Request) throws -> HTTPResponse {
			debugPrint("Hit app delete handler.")
			return HTTPResponse(status: .ok)
		}
		
		appRoutes.get(use: helloHandler)
		
		appRoutes.get(ToastyServerRoutes.App.Alexa.account, AmazonAccount.parameter, use: getAccountHandler)
		appRoutes.post(ToastyServerRoutes.App.Alexa.account, use: addAccountHandler) //post body contains AmazonAccount
		appRoutes.delete(ToastyServerRoutes.App.Alexa.account, AmazonAccount.parameter, use: deleteAccountHandler)
		appRoutes.post(ToastyServerRoutes.App.Alexa.fireplace, use: addFireplacesHandler)
		appRoutes.delete(ToastyServerRoutes.App.Alexa.fireplace, use: deleteFireplacesHandler)
	}
}
