//
//  Imp.swift
//  Toasty
//
//  Created by Scott Lucas on 6/4/18.
//

import Foundation
import Vapor
import FluentPostgreSQL
import Crypto

struct ImpFireplaceAction: Encodable, Content { //action directive from Alexa ==> deviceCloud ==> Imp
    var name:Directive
    enum Directive: String, Codable, Content {
        case on = "TurnOn", off = "TurnOff", update = "Update"
    }
    init? (action: String) {
        guard Directive(rawValue: action) != nil else { return nil }
        name = Directive(rawValue: action)!
    }
    
    init (action: Directive) {
        name = action
    }
}

struct ImpFireplaceStatus: Codable { //messages for status communication deviceCloud ==> Alexa
    var ack: AcknowledgeMessage
    var value: ValueMessage? //matches what's needed for status response to Alexa
    var uncertaintyInMilliseconds: Int?
    
    enum AcknowledgeMessage: String, Codable {
        case acceptedOn = "ON", acceptedOff = "OFF", rejected = "UNKNOWN", updating = "UPDATING", notAvailable = "NA"
    }
    
    enum ValueMessage: String, Codable {
        case ON, OFF
    }
    
    enum CodingKeys: String, CodingKey {
        case ack, value
    }
    
    init(ack: AcknowledgeMessage = .notAvailable) {
        self.ack = ack
        value = ValueMessage(rawValue: (self.ack.rawValue))
    }
}

struct ImpKey: Codable, PostgreSQLUUIDModel {
	typealias Database = PostgreSQLDatabase
	var id: UUID?
	var privateKey: Data
	var publicKey: String
	var creationDate: Date
	var iv: Data
	var tag: Data

	init? (private prKey: String, public puKey: String) {
		publicKey = puKey
		guard
			let k = ENVVariables.dataKey.data(using: .utf8),
			let dataKey = try? SHA256.hash(k) else { return nil }
		iv = Data(bytes: Array<UInt8>.init(repeating: 0, count: 12).map { _ in return UInt8.random(in: 0...0xFF) })
		do {
			let (ciphertext, ctag) = try AES256GCM.encrypt(prKey, key: dataKey, iv: iv)
			privateKey = ciphertext
			tag = ctag
			creationDate = Date()
		} catch {
			print (error)
			return nil
		}
	}
	
	func getPrivateKey () -> String? {
		guard
			let k = ENVVariables.dataKey.data(using: .utf8),
			let dataKey = try? SHA256.hash(k),
			let prKeyData = try? AES256GCM.decrypt(privateKey, key: dataKey, iv: iv, tag: tag)
			else { return nil }
		let str = String(data: prKeyData, encoding: .utf8)
		return str
	}
}

extension ImpFireplaceStatus { //decoding strategy, only used when receiving messages from Imp
    init (from decoder: Decoder) throws {
        let allValues = try decoder.container(keyedBy: CodingKeys.self)
        ack = try allValues.decode(AcknowledgeMessage.self, forKey: .ack)
        value = ValueMessage(rawValue: ack.rawValue)
    }
}

extension ImpFireplaceStatus { //encoding strategy, only used when sending message to Alexa
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(value, forKey: .value)
    }
}

//struct CodableFireplace: Codable, Content { //structure to decode the fireplaces passed from Imp ==> device cloud
//    var name:String
//    var level: Fireplace.FireLevel
//    var power: Fireplace.PowerStatus
//    var url:String
//}

