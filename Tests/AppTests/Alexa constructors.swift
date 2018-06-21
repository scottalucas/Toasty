//
//  Alexa constructors.swift
//  AppTests
//
//  Created by Scott Lucas on 6/18/18.
//

import Foundation

struct AlexaJson {
    static  let fpOffReq = // param: enpoint ID
    """
{
"directive": {
"header": {
"namespace": "Alexa.PowerController",
"name": "TurnOff",
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
    
    static let fpOnOffReq = // param: OnOff, messageID, correlationToken, AccessToken, enpoint ID
    """
{
    "directive": {
        "header": {
            "namespace": "Alexa.PowerController",
            "name": "%@",
            "payloadVersion": "3",
            "messageId": "%@",
            "correlationToken": "%@"
        },
        "endpoint": {
            "scope": {
                "type": "BearerToken",
                "token": "%@"
            },
            "endpointId": "%@",
            "cookie": {}
        },
        "payload": {}
    }
}
"""
    
    static let discoveryReq = //param: msgId, token
    """
{
    "directive": {
        "header": {
            "namespace": "Alexa.Discovery",
            "name": "Discover",
            "payloadVersion": "3",
            "messageId": "%@"
        },
        "payload": {
            "scope": {
                "type": "BearerToken",
                "token": "%@"
            }
        }
    }
}
"""
}
