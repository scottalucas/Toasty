//
//  Error.swift
//  Toasty
//
//  Created by Scott Lucas on 6/20/18.
//

import Foundation

struct AlexaError: Error, ToastyError {
	var id:Category
	var file: String?
	var function: String?
	var line: Int?
	
	enum Category {
		case couldNotDecodeDiscovery, couldNotRetrieveUserAccount, couldNotDecodePowerControllerDirective, couldNotDecodeProperty, couldNotDecode, couldNotEncode, didNotUnderstandFireplaceCommand, failedToLookupUser, noCorrespondingToastyAccount, childFireplacesNotFound, couldNotRetrieveFireplace, placeholderAccountNotFound, unableToCreateLWAScopeError, couldNotDecodeStateRequest, couldNotCreateResponse, unknown
	}
	var description:String {
		switch id {
		case .couldNotDecodeDiscovery:
			return "Could not decode Alexa discovery message."
		case .couldNotDecodeStateRequest:
			return "Could not decode status report from Alexa."
		case .couldNotRetrieveUserAccount:
			return "Could not retrieve user account."
		case .couldNotDecodePowerControllerDirective:
			return "Could not decode instructions from Alexa."
		case .couldNotEncode:
			return "Failed to encode a value."
		case .couldNotDecode:
			return "Failed to decode a value."
		case .failedToLookupUser:
			return "Could not find a user associated with the endpoint sent by Alexa."
		case .noCorrespondingToastyAccount:
			return "Unable to find a related account on the Toasty cloud."
		case .childFireplacesNotFound:
			return "Did not find any fireplaces associated with the Amazon user."
		case .placeholderAccountNotFound:
			return "Could not retrieve placeholder account."
		case .couldNotDecodeProperty:
			return "Could not decode property value."
		case .didNotUnderstandFireplaceCommand:
			return "Did not understand fireplace action command."
		case .couldNotCreateResponse:
			return "Could not create a response to Alexa."
		case .unableToCreateLWAScopeError:
			return "Unable to create error for LWA scope response."
		case .couldNotRetrieveFireplace:
			return "Could not retrieve fireplace."
		case .unknown:
			return "Unknown Alexa error."
		}
	}
	
	var localizedDescription: String {
		var formatString = String("\nAlexa Error description: \(description)")
		formatString.append((file != nil) ? String("\n\tFile: \(file!)") : "")
		formatString.append((function != nil) ? String("\n\tFunction: \(function!)") : "")
		formatString.append((line != nil) ? String("\n\tLine: \(line!)") : "")
		logger.error(formatString)
		return formatString
	}
	
	var context: [String:String] {
		return [
			"RETRYURL": ToastyServerRoutes.site?.appendingPathComponent(ToastyServerRoutes.Lwa.root).appendingPathComponent(ToastyServerRoutes.Lwa.login).absoluteString ?? "not available", //note, took out a slash here
			"ERROR" : description,
			"ERRORURI" : "",
			"ERRORFILE" : file ?? "not captured",
			"ERRORFUNCTION" : function ?? "not captured",
			"ERRORLINE" : line.debugDescription
		]
	}
	init(_ id: Category, file: String? = nil, function: String? = nil, line: Int? = nil) {
		self.id = id
		self.file = file
		self.function = function
		self.line = line
	}
}

struct ImpError: Error, ToastyError {
	var id:Category
	var file: String?
	var function: String?
	var line: Int?
	
	enum Category {
		//        case badUrl, couldNotEncodeImpAction, couldNotDecodeImpResponse, couldNotDecodePowerControllerDirective, failedToEncodeResponse, failedToLookupUser, noCorrespondingToastyAccount, childFireplacesNotFound, unknown
		case fireplaceUnavailable, fireplaceOffline, operationNotSupported, badUrl, couldNotEncodeImpAction, couldNotDecodeImpResponse, foundDefaultUser, lowPower, couldNotCreateToken, unknown
	}
	var description:String {
		switch id {
		case .fireplaceUnavailable:
			return "Fireplace is not available."
		case .fireplaceOffline:
			return "Fireplace is offline."
		case .operationNotSupported:
			return "Fireplace does not support the requested operation."
		case .badUrl:
			return "The URL for the fireplace is not structured properly."
		case .couldNotEncodeImpAction:
			return "Failed to encode the Imp action into a format to send via http."
		case .couldNotDecodeImpResponse:
			return "The reponse from the fireplace could not be decoded."
		case .foundDefaultUser:
			return "Default user already exists."
		case .lowPower:
			return "Low power."
		case .couldNotCreateToken:
			return "Could not create token."
		case .unknown:
			return "Unknown Imp error."
		@unknown default:
			break
		}
	}
	
	var localizedDescription: String {
		var formatString: String = String("\nImp Error description: \(description)")
		formatString.append((file != nil) ? String("\n\tFile: \(file!)") : "")
		formatString.append((function != nil) ? String("\n\tFunction: \(function!)") : "")
		formatString.append((line != nil) ? String("\n\tLine: \(line!)") : "")
		logger.error(formatString)
		return formatString
	}
	
	var context: [String:String] {
		return [
			"RETRYURL": ToastyServerRoutes.site?.appendingPathComponent(ToastyServerRoutes.Lwa.root).appendingPathComponent(ToastyServerRoutes.Lwa.login).absoluteString ?? "not available",  //note, took out a slash here
			"ERROR" : description,
			"ERRORURI" : "",
			"ERRORFILE" : file ?? "not captured",
			"ERRORFUNCTION" : function ?? "not captured",
			"ERRORLINE" : line.debugDescription
		]
	}
	init(_ id: Category, file: String? = nil, function: String? = nil, line: Int? = nil) {
		self.id = id
		self.file = file
		self.function = function
		self.line = line
	}
}

extension ImpError {
	func alexaError(forAlexaMessage message: AlexaMessage) -> AlexaErrorResponse {
		switch self.id {
		case .badUrl:
			return AlexaErrorResponse.init(requestedVia: message, errType: .endpointUnreachable, message: self.description)
		case .couldNotEncodeImpAction:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidValue, message: self.description)
		case .couldNotDecodeImpResponse:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		case .fireplaceOffline:
			return AlexaErrorResponse.init(requestedVia: message, errType: .notInOperation, message: self.description)
		case .fireplaceUnavailable:
			return AlexaErrorResponse.init(requestedVia: message, errType: .endpointUnreachable, message: self.description)
		case .foundDefaultUser:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidValue, message: self.description)
		case .operationNotSupported:
			return AlexaErrorResponse.init(requestedVia: message, errType: .notSupported, message: self.description)
		case .lowPower:
			return AlexaErrorResponse.init(requestedVia: message, errType: .lowPower, message: self.description)
		case .couldNotCreateToken:
			return AlexaErrorResponse(requestedVia: message, errType: .internalError, message: self.description)
		case .unknown:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		@unknown default:
			break
		}
	}
}

struct LoginWithAmazonError: Error, ToastyError {
	var id:Category
	var file: String?
	var function: String?
	var line: Int?
	
	enum Category {
		case serverMisconfigured, serverError, couldNotInitializeAccount, unauthorized, couldNotRetrieveAmazonAccount (LWACustomerProfileResponseError?), failedToRetrieveAuthToken (LWAAuthTokenResponseError?), failedToRetrieveAccessToken (LWAAccessTokenGrantError?), failedToRetrieveUserScope(LWAUserScopeError?), couldNotCreateAccount, couldNotCreateRequest, lwaError, noAvailableFireplaces, couldNotDecode, couldNotCreateFireplaces, accountNotFound, unknown
	}
	var description:String {
		switch id {
		case .serverMisconfigured:
			return "Server misconfigured."
		case .serverError:
			return "Server error."
		case .couldNotInitializeAccount:
			return "Could not initialize account on Toasty device cloud."
		case .unauthorized:
			return "Amazon account is not authorized to communicate with Toasty device cloud."
		case .couldNotRetrieveAmazonAccount(let err): //LWACustomerProfileResponseError
			return err?.error_description ?? "no details available."
		case .failedToRetrieveAuthToken(let err): //LWAAuthTokenResponseError
			return err?.error_description ?? "no details available."
		case .failedToRetrieveAccessToken(let err): //LWAAccessTokenGrantError
			return err?.error_description ?? "no details available."
		case .failedToRetrieveUserScope(let err):
			return err?.message ?? "no details available."
		case .couldNotCreateAccount:
			return "Could not create a Toasty device cloud account."
		case .couldNotCreateRequest:
			return "Could not create an authentication request."
		case .lwaError:
			return "Login with Amazon returned an error."
		case .noAvailableFireplaces:
			return "Toasty device cloud account does not have any fireplaces."
		case .couldNotDecode:
			return "Login wth Amazon sent a response that Toasty could not decode."
		case .couldNotCreateFireplaces:
			return "Unable to create fireplace records in Toasty."
		case .accountNotFound:
			return "Could not find account in Toasty."
		case .unknown:
			return "Unknown LWA error."
		@unknown default:
			break
		}
	}
	
	var localizedDescription: String {
		var formatString: String = String("\nLWA Error description: \(description)")
		formatString.append((file != nil) ? String("\n\tFile: \(file!)") : "")
		formatString.append((function != nil) ? String("\n\tFunction: \(function!)") : "")
		formatString.append((line != nil) ? String("\n\tLine: \(line!)") : "")
		formatString.append((uri != nil) ? String("\n\tURI: \(uri!)") : "")
		//        logger.error(formatString)
		return formatString
	}
	
	var uri: String? {
		switch id {
		case .failedToRetrieveAccessToken(let err):
			return err?.error_uri
		default:
			return nil
		}
	}
	var context: [String:String] {
		return [
			"RETRYURL": ToastyServerRoutes.site?.appendingPathComponent(ToastyServerRoutes.Lwa.root).appendingPathComponent(ToastyServerRoutes.Lwa.login).absoluteString ?? "not available",  //note, took out a slash here
			"ERROR" : description,
			"ERRORURI" : uri ?? "",
			"ERRORFILE" : file ?? "not captured",
			"ERRORFUNCTION" : function ?? "not captured",
			"ERRORLINE" : line.debugDescription
		]
	}
	init(_ id: Category, file: String?, function: String?, line: Int?) {
		self.id = id
		self.file = file
		self.function = function
		self.line = line
	}
}

extension LoginWithAmazonError {
	func alexaError(forAlexaMessage message: AlexaMessage) -> AlexaErrorResponse {
		switch self.id {
		case .serverMisconfigured:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		case .serverError:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		case .couldNotInitializeAccount:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		case .unauthorized:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidCredential, message: self.description)
		case .couldNotRetrieveAmazonAccount: //LWACustomerProfileResponseError
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidCredential, message: self.description)
		case .failedToRetrieveAuthToken: //LWAAuthTokenResponseError
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidCredential, message: self.description)
		case .failedToRetrieveAccessToken: //LWAAccessTokenGrantError
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidCredential, message: self.description)
		case .failedToRetrieveUserScope:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidValue, message: self.description)
		case .couldNotCreateAccount:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidCredential, message: self.description)
		case .couldNotCreateRequest:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidDirective, message: self.description)
		case .lwaError:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		case .noAvailableFireplaces:
			return AlexaErrorResponse.init(requestedVia: message, errType: .noSuchEndpoint, message: self.description)
		case .couldNotDecode:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidDirective, message: self.description)
		case .couldNotCreateFireplaces:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		case .accountNotFound:
			return AlexaErrorResponse.init(requestedVia: message, errType: .invalidCredential, message: self.description)
		case .unknown:
			return AlexaErrorResponse.init(requestedVia: message, errType: .internalError, message: self.description)
		@unknown default:
			break
		}
	}
}

protocol ToastyError {
	var file: String?  {get set}
	var function: String?  {get set}
	var line: Int?  {get set}
	var localizedDescription: String {get}
}

struct ErrorFormat {
	static func forError(error: Error) -> String {
		switch error {
		case let err as ToastyError:
			return String("""
				
				*********************** TOASTY ERROR ***************************
				\(err.localizedDescription))
				********************** END TOASTY ERROR*************************
				
				""")
		case let err as AlexaErrorResponse:
			return String("""
				
				*********************** ALEXA RESPONSE ERROR ****************************
				Endpoint ID: \(err.event.endpoint.endpointId)
				Error type: \(err.event.payload.type ?? "No type")
				Error message: \(err.event.payload.message ?? "No message")
				********************** END ALEXA RESPONSE ERROR**************************
				
				""")
		case let err as NSError:
			return String("""
				
				*********************** NSURL ERROR ****************************
				Error description: \(String(describing: err.userInfo["NSLocalizedDescription"]))
				Failing url: \(String(describing: err.userInfo["NSErrorFailingURLKey"]))
				********************** END NSURL ERROR**************************
				
				""")
			
		default:
			return String(
				"""
				*********************** GENERAL ERROR ****************************
				\(error.localizedDescription)
				********************** END GENERAL ERROR**************************
				
				""")
		}
	}
}



