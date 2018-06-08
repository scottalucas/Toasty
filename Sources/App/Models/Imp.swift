//
//  Imp.swift
//  Toasty
//
//  Created by Scott Lucas on 6/4/18.
//

import Foundation
import Vapor



struct ImpFireplaceAction: Encodable, Content {
    var action:Directive
    enum Directive: String, Codable, Content {
        case TurnOn, TurnOff
    }
    init (action: String) throws {
        guard Directive(rawValue: action) != nil else { throw Abort(.badRequest, reason: "Received bad or malformed directive from Alexa: \(action), expected TurnOn or TurnOff")}
        self.action = Directive(rawValue: action)!
    }
}

struct ImpFireplaceAck: Decodable {
    var ack: AcknowledgeMessage
    
    enum AcknowledgeMessage: String, Decodable {
        case accepted, rejected, notAvailable
    }
    
    enum CodingKeys: String, CodingKey {
        case ack
    }
    
    init() {
        ack = .notAvailable
    }
}

extension ImpFireplaceAck { //decoding strategy
    init (from decoder: Decoder) throws {
        let allValues = try decoder.container(keyedBy: CodingKeys.self)
        ack = try allValues.decode(AcknowledgeMessage.self, forKey: .ack)
    }
}

struct ImpFireplaceStatus: Codable, Content {
    let status:Status
    enum Status: String, Codable {
        case ON, OFF, NotAvailable
    }
}


