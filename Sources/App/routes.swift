import FluentPostgreSQL
import Vapor
import Fluent
/// Register your application's routes here.
public func routes(_ router: Router) throws {
	router.get {req -> Response in
		let logger = try? req.make(Logger.self)
		logger?.debug("Starting router...")
		guard
			let site = ToastyServerRoutes.site?.appendingPathComponent(ToastyServerRoutes.Lwa.root).appendingPathComponent(ToastyServerRoutes.Lwa.login).absoluteString
			else {throw Abort(.notImplemented, reason: "Server Error: Main site URL not defined")}
		return req.redirect(to: site)
	}
//	let loginWithAmazonController = LoginWithAmazonController()
	let alexaController = AlexaController()
	let testController = TestController()
	let fireplaceController = FireplaceManagementController()
	let appController = AppController()
	let alexaAccountController = AlexaAppController()
//	try router.register(collection: loginWithAmazonController)
	try router.register(collection: alexaController)
	try router.register(collection: testController)
	try router.register(collection: fireplaceController)
	try router.register(collection: appController)
	try router.register(collection: alexaAccountController)
}

struct ToastyServerRoutes {
	static var site: URL? {
		return URL(string: ENVVariables.siteUrl)
	}
	struct Lwa { //routes that handle transactions from Login with Amazon OAuth
		static let root = "lwa"
		static let auth = "auth"
		static let login = "login"
		static let loginPage = "loginPage"
	}
	struct Alexa { //routes that handle transactions from Alexa
		static let root = "Alexa"
		static let discovery = "Discovery"
	}
	struct Fireplace { //routes that handle transactions from Electric Imp
		static let root = "imp"
		struct Update {
			static let root = "update"
			static let timezone = "timezone"
			static let weatherUrl = "weatherUrl"
			static let rotateKey = "rotateKey"
            static let updateBatteryLevel = "batteryLevel"
		}
	}
	struct Test {
		static let root = "test"
		static let reset = "reset"
		static let apns = "apns"
		static let setup = "setUpUser"
	}
	struct App { //routes that handle transactions from the phone app
		static let root = "app"
		static let user = "user"
		static let fireplace = "fireplace"
		struct Alexa {
			static let root = "alexa"
			static let fireplace = "fireplace"
			static let enable = "enable"
			static let disable = "disable"
			static let account = "account"
		}
	}
}
