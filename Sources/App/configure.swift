import FluentPostgreSQL
import DatabaseKit
import Vapor
import Leaf

public func configure(
	_ config: inout Config,
	_ env: inout Environment,
	_ services: inout Services
	) throws {
	try services.register(FluentPostgreSQLProvider())
	let router = EngineRouter.default()
	try routes(router)
	services.register(router, as: Router.self)
	services.register(LogMiddleware.self)
	
	var middlewares = MiddlewareConfig()
	middlewares.use(ErrorMiddleware.self)
	middlewares.use(SessionsMiddleware.self)
	middlewares.use(LogMiddleware.self)
	services.register(middlewares)
	config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
	//
	
	services.register(Logger.self) { container in
		return PrintLogger()
	}
	//
	try services.register(LeafProvider())
	config.prefer(LeafRenderer.self, for: ViewRenderer.self)
	// Configure a database
	var databasesConfig = DatabasesConfig()
	let databaseConfig: PostgreSQLDatabaseConfig
	if let url = Environment.get("DATABASE_URL") {
		logger.log("getting database url: \(url)", at: .debug, file: #file, function: #function, line: #line, column: #column)
		databaseConfig = PostgreSQLDatabaseConfig(url: url)!
	} else if let url = Environment.get("DB_POSTGRESQL") {
		databaseConfig = PostgreSQLDatabaseConfig(url: url)!
	} else {
		let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
		let username = Environment.get("DATABASE_USER") ?? "toasty"
		let password = Environment.get("DATABASE_PASSWORD") ?? "Lynnseed"
		let databaseName: String
		let databasePort: Int
		if (env == .testing) {
			databaseName = "vapor-test"
			if let testPort = Environment.get("DATABASE_PORT") {
				databasePort = Int(testPort) ?? 5433
			} else {
				databasePort = 5433
			}
		} else {
			databaseName = Environment.get("DATABASE_DB") ?? "postgres"
			databasePort = 5432
		}
		
		databaseConfig = PostgreSQLDatabaseConfig(
			hostname: hostname,
			port: databasePort,
			username: username,
			database: databaseName,
			password: password)
	}
	let database = PostgreSQLDatabase(config: databaseConfig)
	databasesConfig.add(database: database, as: .psql)
	databasesConfig.enableLogging(on: .psql)
	services.register(databasesConfig)
	
	var migrations = MigrationConfig()
	migrations.add(model: Phone.self, database: .psql)
	migrations.add(model: Fireplace.self, database: .psql)
	migrations.add(model: AmazonAccount.self, database: .psql)
	migrations.add(model: UserFireplacePivot.self, database: .psql)
	migrations.add(model: FireplaceAmazonPivot.self, database: .psql)
	services.register(migrations)
	
	//configure server to work in container
	let port: Int = Int(Environment.get(ENVVariables.port) ?? "8080") ?? 8080
	logger.log("Starting server on port \(port)", at: .debug, file: #file, function: #function, line: #line, column: #column)
	let serverConfigure = NIOServerConfig.default(hostname: "0.0.0.0", port: port)
	services.register(serverConfigure)
	
	// Shell
	//	services.register(Shell.self)
}

struct ENVVariables {
	static let siteUrl:String = "SITEURL"
	static let lwaClientId:String = "LWACLIENTID"
	static let lwaClientSecret:String = "LWACLIENTSECRET"
	static let port: String = "PORT"
}


