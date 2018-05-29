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
//    middlewares.use(ErrorMiddleware.self)
    middlewares.use(SessionsMiddleware.self)
    services.register(middlewares)
//    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
//
    
    services.register(Logger.self) { container in
        return PrintLogger()
    }
    //
    try services.register(LeafProvider())
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)

    // Configure a database
//    try services.register(FluentPostgreSQLProvider())
    var databases = DatabasesConfig()
    guard let hostname = Environment.get("DATABASEHOSTNAME") else {throw Abort(.failedDependency, reason: "Database host name not found")}
    guard let username = Environment.get("DATABASEUSER") else {throw Abort(.failedDependency, reason: "Database username name not found")}
    guard let databaseName = Environment.get("DATABASEDB") else {throw Abort(.failedDependency, reason: "Database name not found")}
    guard let password = Environment.get("DATABASEPASSWORD") else {throw Abort(.failedDependency, reason: "Database password name not found")}
    let databaseConfig = PostgreSQLDatabaseConfig(
        hostname: hostname,
        username: username,
        database: databaseName,
        password: password)
    let database = PostgreSQLDatabase(config: databaseConfig)
    databases.add(database: database, as: .psql)
    services.register(databases)

    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .psql)
    migrations.add(model: Fireplace.self, database: .psql)
    migrations.add(model: AmazonAccount.self, database: .psql)
    migrations.add(model: AlexaFireplace.self, database: .psql)
    migrations.add(model: SessionData.self, database: .psql)
    services.register(migrations)
}

struct ENVVariables {
    static let siteUrl:String = "SITEURL"
    static let lwaClientId:String = "LWACLIENTID"
    static let lwaClientSecret:String = "LWACLIENTSECRET"
}
