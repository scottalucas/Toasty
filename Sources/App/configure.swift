import FluentPostgreSQL
import DatabaseKit
import Vapor
import Leaf


public func configure(
	_ config: inout Config,
	_ env: inout Environment,
	_ services: inout Services
	) throws {
    logger.log("starting configure...", at: .debug, file: #file, function: #function, line: #line, column: #column)
	try services.register(FluentPostgreSQLProvider())
	let router = EngineRouter.default()
	try routes(router)
	services.register(router, as: Router.self)
	services.register(LogMiddleware.self)
	
	var middlewares = MiddlewareConfig()
	middlewares.use(ErrorMiddleware.self)
	middlewares.use(SessionsMiddleware.self)
//	middlewares.use(LogMiddleware.self)
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
    logger.log("Entering database setup, retrieved ENV \(Environment.get("DATABASE_URL") ?? "not found")", at: .debug, file: #file, function: #function, line: #line, column: #column)
	if var url = Environment.get("DATABASE_URL") {
		logger.log("getting database url: \(url)", at: .debug, file: #file, function: #function, line: #line, column: #column)
//		url = "\(url)?sslmode=require"
		logger.log("getting database url: \(url)", at: .debug, file: #file, function: #function, line: #line, column: #column)
		databaseConfig = PostgreSQLDatabaseConfig(url: url)!
		logger.log("Database config successful", at: .debug, file: #file, function: #function, line: #line, column: #column)
	} else if let url = Environment.get("DB_POSTGRESQL") {
		logger.log("getting database url: \(url)", at: .debug, file: #file, function: #function, line: #line, column: #column)
		databaseConfig = PostgreSQLDatabaseConfig(url: url)!
	} else {
		logger.log("getting database url not found, using def.", at: .debug, file: #file, function: #function, line: #line, column: #column)
		let hostname = "192.168.1.21"
//        let hostname = "localhost"
		let username = "toasty"
		let password = "Lynnseed"
		let databaseName: String = "postgres"
		let databasePort: Int = 5432
		
		databaseConfig = PostgreSQLDatabaseConfig(
			hostname: hostname,
			port: databasePort,
			username: username,
			database: databaseName,
			password: password)
	}
    logger.log("Database host: \(databaseConfig.serverAddress) username: \(databaseConfig.username) password: \(databaseConfig.password ?? "not found") database name: \(databaseConfig.database ?? "not found")", at: .info, file: #file, function: #function, line: #line, column: #column)
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
    migrations.add(model: BatteryLog.self, database: .psql)
	services.register(migrations)
	
	//configure server to work in container
	logger.log("Starting server on address \(ENV.SERVER), port \(ENV.PORT)", at: .debug, file: #file, function: #function, line: #line, column: #column)
    let serverConfigure = NIOServerConfig.default(hostname: ENV.SERVER, port: Int(ENV.PORT))
	services.register(serverConfigure)
	
	print(TokenManager.basicToken ?? "No token.")
}

struct ENVVariables {
	static let siteUrl:String = "SITEURL"
	static let lwaClientId:String = "LWACLIENTID"
	static let lwaClientSecret:String = "LWACLIENTSECRET"
	static let port: String = "PORT"
	static let dataKey: String = "myPassword"
}


