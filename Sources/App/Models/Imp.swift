//
//  Imp.swift
//  Toasty
//
//  Created by Scott Lucas on 6/4/18.
//

import Foundation
import Vapor



struct ImpFireplaceAction: Encodable, Content { //action directive from Alexa ==> deviceCloud ==> Imp
    var name:Directive
    enum Directive: String, Codable, Content {
        case on = "TurnOn", off = "TurnOff", update = "Update"
    }
    init (action: String) throws {
        guard Directive(rawValue: action) != nil else { throw AlexaError(.didNotUnderstandFireplaceCommand, file: #file, function: #function, line: #line)}
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
        case acceptedOn = "ON", acceptedOff = "OFF", rejected = "UNKNOWN", notAvailable = "NA"
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

