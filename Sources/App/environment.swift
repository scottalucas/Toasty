//
//  environment.swift
//  Toasty
//
//  Created by Scott Lucas on 4/9/19.
//

import Foundation

struct ENV {
	static var USE_PRODUCTION_FOR_APNS: Bool {
		get {
			if let envProd = ProcessInfo.processInfo.environment["USE_PRODUCTION_FOR_APNS"] {
				return envProd == "true" ? true : false
			} else {
				return false
			}
		}
	}
	static var KEY_ID: String = ProcessInfo.processInfo.environment["KEY_ID"] ??  "not found"
	static var TEAM_ID: String = ProcessInfo.processInfo.environment["TEAM_ID"] ?? "not found"
	static var APP_ID: String = ProcessInfo.processInfo.environment["APP_ID"] ?? "not found"
	static var PRIVATE_KEY_PATH:String = ProcessInfo.processInfo.environment["PRIVATE_KEY_PATH"] ?? "not found"
	static var PRIVATE_KEY_PASSWORD: String = ProcessInfo.processInfo.environment["PRIVATE_KEY_PASSWORD"] ?? "not found"
	static var SERVER: String = ProcessInfo.processInfo.environment["SERVER"] ?? "0.0.0.0"
	static var PORT: UInt16 = UInt16(ProcessInfo.processInfo.environment["PORT"] ?? "8181") ?? 8181
	static var DATABASE_URL:String = ProcessInfo.processInfo.environment["DATABASE_URL"] ?? "postgresql://slucas:Lynnseed@172.20.7.181:5432/postgres"
	static var RECEIPT_VALIDATION_HOST = ProcessInfo.processInfo.environment["RECEIPT_VALIDATION_HOST"] ?? "not found"
	static var IAP_PASSWORD = ProcessInfo.processInfo.environment["IAP_PASSWORD"]
	static var EMAIL_SECRET: String? = ProcessInfo.processInfo.environment["EMAIL_SECRET"]
	static var EMAIL_SMTP_USERNAME: String? = ProcessInfo.processInfo.environment["EMAIL_SMTP_USERNAME"]
	static var EMAIL_SMTP_SERVER: String? = ProcessInfo.processInfo.environment["EMAIL_SMTP_SERVER"]
	static var EMAIL_SMTP_PASSWORD: String? = ProcessInfo.processInfo.environment["EMAIL_SMTP_PASSWORD"]
	
	static var HIGH_TEMP_NOTIFICATION_TRIGGER: Int = 85
	static var HOT_WEATHER_POLL_INTERVAL: Int = 60 * 60
	static var HOT_WEATHER_POLL_START_MINUTE: Int = 1
	static var HOUR_TO_POLL_FOR_FORECAST: Int = 20
}
