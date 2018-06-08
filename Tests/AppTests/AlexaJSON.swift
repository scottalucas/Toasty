//
//  AlexaJSON.swift
//  Toasty
//
//  Created by Scott Lucas on 6/7/18.
//

import Foundation

struct alexaJson {
    static let fpOnReq = """
{
    "directive": {
        "header": {
            "namespace": "Alexa.PowerController",
            "name": "TurnOn",
            "payloadVersion": "3",
            "messageId": "1bd5d003-31b9-476f-ad03-71d471922820",
            "correlationToken": "dFMb0z+PgpgdDmluhJ1LddFvSqZ/jCc8ptlAKulUj90jSqg=="
        },
        "endpoint": {
            "scope": {
                "type": "BearerToken",
                "token": "access-token-from-skill"
            },
            "endpointId": "%@",
            "cookie": {}
        },
        "payload": {}
    }
}
"""
//    static let fpOnReq = """
//    {"directive":{"header":{"namespace":"Alexa.PowerController","name":"TurnOn","payloadVersion":"3","messageId":"1bd5d003-31b9-476f-ad03-71d471922820","correlationToken":"dFMb0z+PgpgdDmluhJ1LddFvSqZ/jCc8ptlAKulUj90jSqg=="},"endpoint":{"scope":{"type":"BearerToken","token":"access-token-from-skill"},"endpointId":"%@","cookie":{}},"payload":{}}}
//    """
}
