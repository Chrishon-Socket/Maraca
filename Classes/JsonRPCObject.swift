//
//  JsonRPCObject.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 11/18/19.
//

import Foundation

/// Intercepts incoming JSON objects and translates into JSON-RPC format
internal class JsonRPCObject: CustomStringConvertible {
    
    let jsonrpc: String?
    
    // This can be an Int or String according to the JSON-RPC docs:
    // https://docs.socketmobile.com/capture/json-rpc/en/latest/methods.html
    let id: Any?
    let method: String?
    let params: [String: Any]?
    let result: [String: Any]?
    let dictionary: [String: Any]
    
    init(dictionary: [String: Any]) {
        self.dictionary = dictionary
        self.jsonrpc = dictionary[MaracaConstants.Keys.jsonrpc.rawValue] as? String
        self.id = dictionary[MaracaConstants.Keys.id.rawValue]
        self.method = dictionary[MaracaConstants.Keys.method.rawValue] as? String
        self.params = dictionary[MaracaConstants.Keys.params.rawValue] as? [String: Any]
        self.result = dictionary[MaracaConstants.Keys.result.rawValue] as? [String: Any]
    }
    
    internal func getAppInfo() -> [String: Any]? {
        var dictionary: [String: Any] = [:]
        
        guard
            let appID = getParamsValue(for: MaracaConstants.Keys.appId.rawValue) as? String,
            let appKey = getParamsValue(for: MaracaConstants.Keys.appKey.rawValue) as? String,
            let developerID = getParamsValue(for: MaracaConstants.Keys.developerId.rawValue) as? String
            else { return nil }
        
        dictionary[MaracaConstants.Keys.appId.rawValue] = appID
        dictionary[MaracaConstants.Keys.appKey.rawValue] = appKey
        dictionary[MaracaConstants.Keys.developerId.rawValue] = developerID
        
        return dictionary
    }
    
    internal func getParamsValue(for key: String) -> Any? {
        return params?[key]
    }
    
    internal var description: String {
        var toString: String = ""
        
        toString = "JSON RPC version: \(String(describing: jsonrpc))\n"
        
        toString = "ID: \(String(describing: id))\n"
        
        toString += "Method: \(String(describing: self.method))\n"
        
        if let params = params {
            for (key, value) in params {
                toString = "Param key: \(key). Value: \(value)\n"
            }
        }
        
        if let result = result {
            for (key, value) in result {
                toString = "Result key: \(key). Value: \(value)\n"
            }
        }
        
        return toString
    }
}
