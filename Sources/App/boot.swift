import Vapor

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    // your code here
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 7.0
    sessionConfig.timeoutIntervalForResource = 7.0
}
