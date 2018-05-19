import FluentPostgreSQL
import Vapor
import Leaf

public func configure(
    _ config: inout Config,
    _ env: inout Environment,
    _ services: inout Services
    ) throws {
//    try services.register(FluentPostgreSQLProvider())
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
//
    services.register(PrintLogger(), as: PrintLogger.self)
//
    try services.register(LeafProvider())
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
//
//    // Configure a database
//    var databases = DatabasesConfig()
//    let hostname = Environment.get("DATABASE_HOSTNAME")
//        ?? "localhost"
//    let username = Environment.get("DATABASE_USER") ?? "vapor"
//    let databaseName = Environment.get("DATABASE_DB") ?? "vapor"
//    let password = Environment.get("DATABASE_PASSWORD")
//        ?? "password"
//    let databaseConfig = PostgreSQLDatabaseConfig(
//        hostname: hostname,
//        username: username,
//        database: databaseName,
//        password: password)
//    let database = PostgreSQLDatabase(config: databaseConfig)
//    databases.add(database: database, as: .psql)
//    services.register(databases)
//
//    var migrations = MigrationConfig()
//    migrations.add(model: AlexaAccount.self, database: .psql)
//    migrations.add(model: User.self, database: .psql)
//    migrations.add(model: Fireplace.self, database: .psql)
//    services.register(migrations)
}
