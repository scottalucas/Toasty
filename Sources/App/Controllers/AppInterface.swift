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
	struct PhoneUpdatePackage: Codable {
		var phoneId: UUID
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
		
		func getUserHandler (req: Request) throws -> Future<Phone> {
			debugPrint("Hit get user handler.")
			guard
				let user = try? req.parameters.next(Phone.self)
			else { throw Abort(.notFound) }
			return user
		}
		
		/*
Adds a phone and associated fireplaces to the database. Success should return status 204 (no content). If we receive unregistered fireplaces or find fireplaces in the databased that weren't sent in the update, return status 206 (partial content) and send the extra/missing fireplaces back to the app.
		Other Errors:
			"Not found" means the user didn't send any fireplaces.
			"Bad request" means we could not decode the package sent by the app
*/
		func addUserHandler(req: Request) throws -> Future<HTTPResponse> {
			debugPrint("Hit app add handler.")
			//app sent package that couldn't be decoded
			guard
				let phoneUpdatePackage = try? req.content.syncDecode(PhoneUpdatePackage.self)
				else { throw Abort(.badRequest) }
			//app sent package without any fireplaces
			
			//need to think about what to do when user doesn't send any fireplaces
//			guard
//				userUpdatePackage.fireplaceIds.count > 0
//				else { throw Abort(.notFound) }
			
			debugPrint(phoneUpdatePackage)
			
			//Return the database records matching the sent fireplaces. Since fireplaces should already be registered, we aren't creating them if they don't exist in the database.
			let matchingFireplacesFromDatabase: Future<[Fireplace]> =
				Fireplace
					.query(on: req)
					.group(.or) { or in
						phoneUpdatePackage.fireplaceIds.forEach { or.filter(\.deviceid == $0) }
					}
					.all()
			
			//there may or may not be a phone registered with this id. Return existing record or create.
			let databasePhoneRecord: Future<Phone> =
				Phone
					.find(phoneUpdatePackage.phoneId, on: req)
					.flatMap(to: Phone.self) { optUser in
						if let usr = optUser {
							return req.future(usr)
						} else {
							return Phone(phoneId: phoneUpdatePackage.phoneId).create(on: req)
						}
			}
			
			//wait for the user and fireplaces to be retrieved from the database
			return flatMap(to: HTTPResponse.self, matchingFireplacesFromDatabase, databasePhoneRecord) { databaseFireplaces, phone in
				
				 //list of fireplace ids sent by app that are not registered in database. Send back to the app.
				let fireplaceIdsMissingFromDatabase =
					Array(Set(phoneUpdatePackage.fireplaceIds)
							.subtracting(Set(databaseFireplaces.compactMap { $0.id })))
				
				//list of fireplace ids associated with this user but not sent by the app (could be from a previous pairing event). Might consider detaching these but for now we'll just send them back to the app.
				let fireplaceIdsNotSentByApp =
					Array(Set(databaseFireplaces.compactMap { $0.id } )
							.subtracting(Set(phoneUpdatePackage.fireplaceIds)))
				
				//get the id for the phone record from the database
				guard
					phone.id != nil
					else {throw Abort(.internalServerError)}
				
				var updates: [Future<HTTPStatus>] = []
				
				//check if the fireplaces from the databased exist in the pivot for this user. If not, add them.
				for fp in databaseFireplaces {
					updates.append(
					fp.phones.isAttached(phone, on: req)
						.flatMap(to: HTTPResponseStatus.self) { attached in
							if !attached {
								return phone.fireplaces
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
			guard let user = try? req.parameters.next(Phone.self) else {return req.future(HTTPResponse(status: .notFound))}
			return user
				.delete(on: req)
				.transform(to: HTTPResponse(status: .noContent))
			
		}
		
		appRoutes.get(use: helloHandler)
		appRoutes.get(ToastyServerRoutes.App.user, Phone.parameter, use: getUserHandler)
		appRoutes.post(ToastyServerRoutes.App.user, use: addUserHandler) //post body contains UserUpdatePackage
		appRoutes.delete(ToastyServerRoutes.App.user, Phone.parameter, use: deleteUserHandler)
	}
}

struct AlexaAppController: RouteCollection {

	struct AlexaUpdatePackage: Codable {
		var amazonAcct: AmazonAccount
		var alexaSimplifiedFireplaces: [AlexaSimplifiedFireplace]
	}
	
	struct AlexaSimplifiedFireplace: Codable, Hashable {
		var name: String
		var id: String
	}
	
	struct AlexaUpdateResponse: Codable, Content {
		var integratedFireplaces: [AlexaSimplifiedFireplace] = []
		var unintegratedFireplaces: [AlexaSimplifiedFireplace] = []
		var notFoundFireplaces: [AlexaSimplifiedFireplace] = []
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
		
		/*
		Input: amazon account Id and an array of fireplace ids available on the end user's device
		
		This function
		1) extracts the account and creates (or gets) the associated amazon account
		2) extracts the inbound fireplaces from the request
		3) looks up registered fireplaces with the same deviceid. (there shouldn't be any missing here if Imp has registered at startup)
		4) matches and returns fireplaces that have the same ids as the requested fireplaces
		5) waits for resolution of account, requested fps, registered fps and integrated fps
		6) updates the name of registered fireplace in the database if necessary and converts array of registered fireplaces into AlexaSimplifiedFireplace array.
		7) converts array of integrated Fireplaces into array of Simplified fps
		8) waits for resolution of integrated and registered simplfied fps, then calculates not found (requested by app but not found in the database), not integrated (all fps requested minus the integrated fireplaces), and integrated (in the account/fireplace pivot, meaning it will be discovered by Alexa, all fps even if not requested) arrays.
		
*/
		func updateAmazonAccount(req: Request) throws -> Future<AlexaUpdateResponse> {
			debugPrint("Hit alexa account add handler.")
			
			let alexaUpdatePackage: Future<AlexaUpdatePackage> = try req.content.decode(AlexaUpdatePackage.self)
			
			//1
			var amazonAccount: Future<AmazonAccount> {
				return alexaUpdatePackage.flatMap(to: AmazonAccount.self) { package in
					return package.amazonAcct
					.create(orUpdate: true, on: req)
				}
			}
			//2
			var simplfiedFireplacesFromApp: Future<[AlexaSimplifiedFireplace]> {
				return alexaUpdatePackage.map(to: [AlexaSimplifiedFireplace].self) { package in
					return package.alexaSimplifiedFireplaces
				}
			}
			
			//3
			var registeredFireplaces: Future<[Fireplace]> {
				return simplfiedFireplacesFromApp
					.flatMap (to: [Fireplace].self) { aFps in
						guard aFps.count > 0 else {return req.future(Array<Fireplace>.init())}
						return Fireplace
							.query(on: req)
							.group(.or) { or in
								aFps.forEach { or.filter(\.deviceid == $0.id) }
							}
							.all()
				}
			}
			
			//4
			var integratedFireplaces: Future<[Fireplace]> {
				return amazonAccount
					.flatMap(to: [Fireplace].self) { acct in
						return (try? acct.fireplaces.query(on: req).all()) ?? req.future(Array<Fireplace>.init()) }
			}
	//5
			return flatMap(to: AlexaUpdateResponse.self, simplfiedFireplacesFromApp, registeredFireplaces, integratedFireplaces, amazonAccount) { requested, registered, integrated, account in
				
				//6
				var registeredAlexaFireplaces: Future<[AlexaSimplifiedFireplace]> {
					let futures: [Future<AlexaSimplifiedFireplace>] = registered.compactMap { fpToSave in
						var mutableFpToSave = fpToSave
						guard let registeredAlexaSimplifiedFp = requested.first(where: { $0.id == mutableFpToSave.deviceid } ) else {return nil}
						if mutableFpToSave.friendlyName != registeredAlexaSimplifiedFp.name {
							mutableFpToSave.friendlyName = registeredAlexaSimplifiedFp.name
							return mutableFpToSave.update(on: req)
								.map(to: AlexaSimplifiedFireplace.self) { savedFp in
									return registeredAlexaSimplifiedFp }
						} else {
							return req.future(registeredAlexaSimplifiedFp)
						}
					}
					return futures.flatten(on: req)
				}
				
				 //7
				var integratedAlexaFireplaces: Future<[AlexaSimplifiedFireplace]> {
					guard let integratedFps = try? account.fireplaces.query(on: req).all() else { return req.future(Array<AlexaSimplifiedFireplace>.init()) }
					return integratedFps.map(to: [AlexaSimplifiedFireplace].self) {intFps in
						return intFps.compactMap{ fp in
							guard let aFp = requested.first(where: { $0.id == fp.deviceid }) else {return nil}
							return aFp
						}
					}
				}
				//8
				return flatMap(to: AlexaUpdateResponse.self, registeredAlexaFireplaces, integratedAlexaFireplaces) { finalRegistered, finalIntegrated in
					let notFound = Array(Set(requested).subtracting(Set(finalRegistered)))
					let notIntegrated = Array(Set(requested).subtracting(Set(finalIntegrated)).subtracting(Set(notFound)))
					return req.future(AlexaUpdateResponse(integratedFireplaces: finalIntegrated, unintegratedFireplaces: notIntegrated, notFoundFireplaces: notFound))
				}
			}
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
		appRoutes.post(ToastyServerRoutes.App.Alexa.account, use: updateAmazonAccount) //post body contains AmazonAccount
		appRoutes.delete(ToastyServerRoutes.App.Alexa.account, AmazonAccount.parameter, use: deleteAccountHandler)
		appRoutes.post(ToastyServerRoutes.App.Alexa.fireplace, use: addFireplacesHandler)
		appRoutes.delete(ToastyServerRoutes.App.Alexa.fireplace, use: deleteFireplacesHandler)
	}
}
