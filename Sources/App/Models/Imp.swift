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
        case acceptedOn, acceptedOff, rejected, notAvailable
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

struct ImpError: Error {
    var id:Category
    var file: String?
    var function: String?
    var line: Int?
    
    enum Category {
        case badUrl, couldNotEncodeImpAction, couldNotDecodeImpResponse, couldNotDecodePowerControllerDirective, failedToEncodeResponse, failedToLookupUser, noCorrespondingToastyAccount, childFireplacesNotFound, unknown
    }
    var description:String {
        switch id {
        case .badUrl:
            return "The URL for the fireplace is not structured properly."
        case .couldNotEncodeImpAction:
            return "Failed to encode the Imp action into a format to send via http."
        case .couldNotDecodeImpResponse:
            return "The reponse from the fireplace could not be decoded."
        case .couldNotDecodePowerControllerDirective:
            return "Could not decode instructions from Alexa."
        case .failedToEncodeResponse:
            return "Error trying to encode a response to update Alexa on fireplace status."
        case .failedToLookupUser:
            return "Could not find a user associated with the endpoint sent by Alexa."
        case .noCorrespondingToastyAccount:
            return "Unable to find a related account on the Toasty cloud."
        case .childFireplacesNotFound:
            return "Did not find any fireplaces associated with the Amazon user."
        case .unknown:
            return "Unknown Alexa error."
        }
    }
    
    var context: [String:String] {
        return [
            "RETRYURL": ToastyAppRoutes.site + "/" + ToastyAppRoutes.lwa.login,
            "ERROR" : description,
            "ERRORURI" : "",
            "ERRORFILE" : file ?? "not captured",
            "ERRORFUNCTION" : function ?? "not captured",
            "ERRORLINE" : line.debugDescription
        ]
    }
    init(id: Category, file: String?, function: String?, line: Int?) {
        self.id = id
        self.file = file
        self.function = function
        self.line = line
    }
}

