//
//  middleware.swift
//  Toasty
//
//  Created by Scott Lucas on 4/20/19.
//

import Foundation
import Vapor

final class LogMiddleware: Middleware {
	let logger: Logger
	
	init(logger: Logger) {
		self.logger = logger
	}
	
	func respond(
		to req: Request,
		chainingTo next: Responder) throws -> Future<Response> {
		logger.info(req.description)
		return try next.respond(to: req)
	}
}

extension LogMiddleware: ServiceType {
	static func makeService(for container: Container) throws -> LogMiddleware {
		return try .init(logger: container.make())
	}
}
