import FluentPostgreSQL
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
    
    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    middlewares.use(SessionsMiddleware.self)
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
    var databases = DatabasesConfig()
    let databaseConfig: PostgreSQLDatabaseConfig
    if let url = Environment.get("DATABASE_URL") {
        databaseConfig = try PostgreSQLDatabaseConfig(url: url)
    } else {
        let databaseName: String
        let databasePort: Int
        if (env == .testing) {
            databaseName = "vapor-test"
            if let testPort = Environment.get("DATABASE_PORT") {
                databasePort = Int(testPort) ?? 5433
            } else {
                databasePort = 5433
            }
        }
        else {
            databaseName = Environment.get("DATABASEDB") ?? "vapor"
            databasePort = 5432
        }
        
        let hostname = Environment.get("DATABASEHOSTNAME") ?? "localhost"
        let username = Environment.get("DATABASEUSER") ?? "vapor"
        let password = Environment.get("DATABASEPASSWORD") ?? "password"
        databaseConfig = PostgreSQLDatabaseConfig(hostname: hostname, port: databasePort, username: username, database: databaseName, password: password)
    }
    let database = PostgreSQLDatabase(config: databaseConfig)
    databases.add(database: database, as: .psql)
    services.register(databases)

    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .psql)
    migrations.add(model: Fireplace.self, database: .psql)
    migrations.add(model: AmazonAccount.self, database: .psql)
    migrations.add(model: AlexaFireplace.self, database: .psql)
//    migrations.add(model: SessionData.self, database: .psql)
    services.register(migrations)
    
    let serverConfigure = NIOServerConfig.default(hostname: "192.168.1.111", port: 8080)
    services.register(serverConfigure)
}

struct ENVVariables {
    static let siteUrl:String = "SITEURL"
    static let lwaClientId:String = "LWACLIENTID"
    static let lwaClientSecret:String = "LWACLIENTSECRET"
}


