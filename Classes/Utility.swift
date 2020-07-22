//
//  Utility.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 7/22/20.
//

import SKTCapture
import WebKit.WKWebView

class Utility {
    
    internal static func convertToDictionary(text: String) -> JSONDictionary? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? JSONDictionary
            } catch {
                DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Error converting JSON string to dictionary. Error: \(error)")
            }
        }
        return nil
    }
    
    internal static func convertJsonRpcToString(_ jsonRpc: JSONDictionary) -> String? {
        do {
            let jsonAsData = try JSONSerialization.data(withJSONObject: jsonRpc, options: [])
            return String(data: jsonAsData, encoding: String.Encoding.utf8)
        } catch let error {
            DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Error converting JsonRpc object to String: \(error)")
            return nil
        }
    }
    
    internal static func constructSKTCaptureProperty(from jsonRPCObject: JsonRPCObject) -> SKTCaptureProperty? {
        
        guard
            let property = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.property.rawValue) as? [String : Any],
            let id = property[MaracaConstants.Keys.id.rawValue] as? Int,
            let type = property[MaracaConstants.Keys.type.rawValue] as? Int,
            let propertyID = SKTCapturePropertyID(rawValue: id),
            let propertyType = SKTCapturePropertyType(rawValue: type)
            else { return nil }
        
        let captureProperty = SKTCaptureProperty()
        captureProperty.id = propertyID
        captureProperty.type = propertyType
        
        return captureProperty
    }
    
    /// Construct a json dictionary with information based on the SKTResult
    /// passed in. Then send the dictionary to the web page that the WKWebView
    /// is displaying
    internal static func sendErrorResponse(withError error: SKTResult, webView: WKWebView, handle: Int?, responseId: Int?) {
        
        // TODO
        // The client for this webview should be the same as
        // the client for the handle?
        // Is it necessary to get a client in for error case,
        // when it would be the same?
        guard
            let webpageURLString = webView.url?.absoluteString,
            let client = Maraca.shared.getClient(for: webpageURLString) else {
                // Temporary
                // But if this is nil, something is wrong
                fatalError()
        }
        
        var errorMessage: String = ""
        
        switch error {
        case .E_INVALIDHANDLE:
            
            if let _ = handle {
                errorMessage = "There is no client or device with the specified handle. The desired client or device may have been recently closed"
            } else {
                errorMessage = "A handle was not specified"
            }
            
        case .E_INVALIDPARAMETER:
            
            errorMessage = "There is a missing or invalid property in the JSON-RPC that is required"
        
        case .E_INVALIDAPPINFO:
            
            errorMessage = "The AppInfo parameters are invalid"
            
        default: return
        }
        
        let errorResponseJsonRpc = constructErrorResponse(error: error, errorMessage: errorMessage, handle: handle, responseId: responseId)
        client.replyToWebpage(with: errorResponseJsonRpc)
        
    }
    
    internal static func constructErrorResponse(error: SKTResult, errorMessage: String, handle: Int?, responseId: Int?) -> JSONDictionary {
        
        let responseJsonRpc: JSONDictionary = [
            MaracaConstants.Keys.jsonrpc.rawValue:  Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.id.rawValue:       responseId ?? 6,
            MaracaConstants.Keys.error.rawValue: [
                MaracaConstants.Keys.code.rawValue: error.rawValue,
                MaracaConstants.Keys.message.rawValue: errorMessage,
                MaracaConstants.Keys.data.rawValue: [
                    MaracaConstants.Keys.handle.rawValue: handle ?? -1
                ]
            ]
        ]
        
        return responseJsonRpc
    }
}
