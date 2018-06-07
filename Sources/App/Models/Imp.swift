//
//  Imp.swift
//  Toasty
//
//  Created by Scott Lucas on 6/4/18.
//

import Foundation
import Vapor

enum ImpFireplaceDirective:String, Codable, Content {
    case TurnOn, TurnOff
    var json:Data {
        let encoder = JSONEncoder()
        switch self {
        case .TurnOn:
            return try! encoder.encode(self)
        case .TurnOff:
            return try! encoder.encode(self)
        }
    }
}

struct ImpFireplaceAction: Encodable, Content {
    let action:String
}

struct ImpFireplaceStatus: Codable, Content {
    let status:ImpStatus
}

enum ImpStatus: String, Codable {
    case ON, OFF, NotAvailable
}
