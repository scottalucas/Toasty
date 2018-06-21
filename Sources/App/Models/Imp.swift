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
        case on = "TurnOn", off = "TurnOff"
    }
    init (action: String) throws {
        guard Directive(rawValue: action) != nil else { throw AlexaError(.didNotUnderstandFireplaceCommand, file: #file, function: #function, line: #line)}
        self.action = Directive(rawValue: action)!
    }
}

struct ImpFireplaceAck: Decodable {
    var ack: AcknowledgeMessage
    
    enum AcknowledgeMessage: String, Decodable {
        case acceptedOn = "ON", acceptedOff = "OFF", rejected = "UNKNOWN", notAvailable = "NA"
    }
    
    enum CodingKeys: String, CodingKey {
        case ack
    }
    
    init(ack: AcknowledgeMessage? = nil) {
        self.ack = ack ?? .notAvailable
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

