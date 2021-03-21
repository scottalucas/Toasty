import Vapor

/// Creates an instance of Application. This is called from main.swift in the run target.
let logger = PrintLogger()

public func app(_ env: Environment) throws -> Application {
    print("starting")
    logger.log("starting...", at: .debug, file: #file, function: #function, line: #line, column: #column)
    var config = Config.default()
    var env = env
    var services = Services.default()
    try configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)
    try boot(app)
    return app
}
