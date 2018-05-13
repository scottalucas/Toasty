import FluentPostgreSQL
import Vapor

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
    services.register(middlewares)
    
    // Configure a database
    var databases = DatabasesConfig()
    let databaseConfig = PostgreSQLDatabaseConfig(
        hostname: "localhost",
        username: "vapor",
        database: "vapor",
        password: "password")
    let database = PostgreSQLDatabase(config: databaseConfig)
    databases.add(database: database, as: .psql)
    services.register(databases)
    
    var migrations = MigrationConfig()
    migrations.add(model: AlexaAccount.self, database: .psql)
    migrations.add(model: User.self, database: .psql)
    migrations.add(model: Fireplace.self, database: .psql)
    services.register(migrations)
}
