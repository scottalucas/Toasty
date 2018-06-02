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
//    try services.register(FluentPostgreSQLProvider())
//    var databases = DatabasesConfig()
//    guard let hostname = Environment.get("DATABASEHOSTNAME") else {throw Abort(.failedDependency, reason: "Database host name not found")}
//    guard let username = Environment.get("DATABASEUSER") else {throw Abort(.failedDependency, reason: "Database username name not found")}
//    guard let databaseName = Environment.get("DATABASEDB") else {throw Abort(.failedDependency, reason: "Database name not found")}
//    guard let password = Environment.get("DATABASEPASSWORD") else {throw Abort(.failedDependency, reason: "Database password name not found")}
//    let databaseConfig = PostgreSQLDatabaseConfig(
//        hostname: hostname,
//        username: username,
//        database: databaseName,
//        password: password)
//    let database = PostgreSQLDatabase(config: databaseConfig)
//    databases.add(database: database, as: .psql)
//    services.register(databases)
    
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
}

struct ENVVariables {
    static let siteUrl:String = "SITEURL"
    static let lwaClientId:String = "LWACLIENTID"
    static let lwaClientSecret:String = "LWACLIENTSECRET"
}
