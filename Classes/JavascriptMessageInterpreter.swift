//
//  JavascriptMessageInterpreter.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 7/22/20.
//

import WebKit
import CaptureSDK

protocol JavascriptMessageInterpreterDelegate: class {
    func interpreter(_ interpreter: JavascriptMessageInterpreter, didReceiveJSONRPC version: String)
    func interpreter(_ interpreter: JavascriptMessageInterpreter, didOpen client: Client, webview: WKWebView)
    func interpreter(_ interpreter: JavascriptMessageInterpreter, didClose client: Client, with handle: ClientHandle)
}

/// Interprets incoming messages from web application
class JavascriptMessageInterpreter: NSObject {
    
    private weak var delegate: JavascriptMessageInterpreterDelegate?
    
    
    
    init(delegate: JavascriptMessageInterpreterDelegate?) {
        super.init()
        self.delegate = delegate
    }
    
    internal func didReceiveCaptureJSMessage(message: WKScriptMessage) -> Bool {
        
        guard let messageBody = message.body as? String, let webview = message.webView else {
            return false
        }
        
        guard let messageHandler = Maraca.MaracaMessageHandlers(rawValue: message.name) else {
            // Enum initializer is optional by default
            // If we don't unwrap, Xcode will complain
            // The initializer is optional because if it receives a `message.name` String that
            // was not specified in the enum, it will return nil.
            //
            // .... In other words, the web page is sending a Javascript message that we did not implement yet
            return false
        }
        
        interpretIncomingJavascript(messageHandler: messageHandler, webview: webview, messageBody: messageBody)
        
        return true
    }
    
    private func interpretIncomingJavascript(messageHandler: Maraca.MaracaMessageHandlers, webview: WKWebView, messageBody: String) {
        
        switch messageHandler {
        case .maracaSendJsonRpc:
            
            let convertedDictionaryResult = Utility.convertToDictionary(text: messageBody)
            
            switch convertedDictionaryResult {
            case .success(let jsonDictionary):
                
                let jsonRPCObject = JsonRPCObject(dictionary: jsonDictionary)
                if let jsonRPCVersion = jsonRPCObject.jsonrpc {
                    delegate?.interpreter(self, didReceiveJSONRPC: jsonRPCVersion)
                }
                
                guard
                    let method = jsonRPCObject.method,
                    let captureJSMethod = Maraca.CaptureJSMethod(rawValue: method)
                    else {
                        DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Unable to build CaptureJSMethod enum value. message body: \(messageBody)\n")
                        DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - dictionary: \(jsonDictionary)\n")
                        DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - jsonRpcObject: \(jsonRPCObject)\n")
                        
                        let error = MaracaError.malformedJson("The JSON RPC object did contain the expected key-value pair: 'method'")
                        sendEarlyFailureMessage(error: error, webview: webview)
                        return
                }
                
                performRequestedAction(captureJSMethod: captureJSMethod, jsonRPCObject: jsonRPCObject, webview: webview)
                
            case .failure(let error):
                
                sendEarlyFailureMessage(error: error, webview: webview)
            }
        }
    }
    
    private func performRequestedAction(captureJSMethod: Maraca.CaptureJSMethod, jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        switch captureJSMethod {
        case Maraca.CaptureJSMethod.openClient:
            
            openClient(with: jsonRPCObject, webview: webview)
            
        case Maraca.CaptureJSMethod.openDevice:
            
            openDevice(jsonRPCObject: jsonRPCObject, webview: webview)
            
        case Maraca.CaptureJSMethod.close:
            
            close(jsonRPCObject: jsonRPCObject, webview: webview)
            
        case Maraca.CaptureJSMethod.getProperty:
            
            getProperty(jsonRPCObject: jsonRPCObject, webview: webview)
            
        case Maraca.CaptureJSMethod.setProperty:
            
            setProperty(jsonRPCObject: jsonRPCObject, webview: webview)
            
        }
    }
    
    private func sendEarlyFailureMessage(error: Error, webview: WKWebView) {
        
        var javascript = "window.maraca.replyJsonRpc('"
        
        let errorJSONStringResult = Utility.convertErrorToJSONString(error: error)
        switch errorJSONStringResult {
        case .success(let errorJSONString):
            javascript.write(errorJSONString)
        case .failure(let error):
            let errorMessage = "Error converting JSON to String: \(error.localizedDescription)"
            javascript.write(errorMessage)
        }
        
        javascript.write("'); ")
        
        webview.evaluateJavaScript(javascript, completionHandler: { (object, error) in
            if let error = error {
                DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Error evaluating javascript expression: \(javascript). Error: \(error)\n")
            } else {
                DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Successfully evaluated javascript expression: \(javascript)\n")
            }
        })
    }
    
    private func openClient(with jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let appInfoDictionary = jsonRPCObject.getAppInfo() else { return }
        
        let appInfo = SKTAppInfo()
        appInfo.appID = appInfoDictionary[MaracaConstants.Keys.appId.rawValue] as? String ?? ""
        appInfo.appKey = appInfoDictionary[MaracaConstants.Keys.appKey.rawValue] as? String ?? ""
        appInfo.developerID = appInfoDictionary[MaracaConstants.Keys.developerId.rawValue] as? String ?? ""
        
        openNewClient(with: appInfo, webview: webview) { [weak self] (result) in
            
            guard let strongSelf = self else {
                fatalError()
            }
            
            switch result {
            case .success(let client):
                let responseJsonRpc: JSONDictionary = [
                    MaracaConstants.Keys.jsonrpc.rawValue:   jsonRPCObject.jsonrpc ?? Maraca.defaultJsonRpcVersion,
                    // The spec says "transport-openclient" but the id is expected to be an integer
                    MaracaConstants.Keys.id.rawValue:        jsonRPCObject.id ?? "transport-openclient",
                    MaracaConstants.Keys.result.rawValue: [
                        MaracaConstants.Keys.handle.rawValue: client.handle
                    ]
                ]
                
                client.replyToWebpage(with: responseJsonRpc)
                
                strongSelf.delegate?.interpreter(strongSelf, didOpen: client, webview: webview)
                
            case .failure(_):
                
                let errorResponseJsonRpc = Utility.constructErrorResponse(error: SKTResult.E_INVALIDAPPINFO,
                                                                         errorMessage: "The AppInfo parameters are invalid",
                                                                         handle: nil,
                                                                         responseId: jsonRPCObject.id as? Int)
                
                var javascript = "window.maraca.replyJsonRpc('"
                
                let jsonStringResult = Utility.convertJsonRpcToString(errorResponseJsonRpc)
                switch jsonStringResult {
                case .success(let jsonString):
                    
                    // Refer to replyJSonRpc and receiveJsonRPC functions
                    // REceive used for when received decoded data
                    // reply for when replying back to web page that you opened the client, set a property etc.
                    
                    
                    javascript.write(jsonString)
                    
                    
                case .failure(let error):
                    let errorJSONStringResult = Utility.convertErrorToJSONString(error: error)
                    switch errorJSONStringResult {
                    case .success(let errorJSONString):
                        javascript.write(errorJSONString)
                    case .failure(let error):
                        let errorMessage = "Error converting JSON to String: \(error.localizedDescription)"
                        javascript.write(errorMessage)
                    }
                }
                
                javascript.write("'); ")
                
                webview.evaluateJavaScript(javascript, completionHandler: { (object, error) in
                    if let error = error {
                        DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Error evaluating javascript expression: \(javascript). Error: \(error)\n")
                    } else {
                        DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Successfully evaluated javascript expression: \(javascript)\n")
                    }
                })
                
            }
        }
    }
    
    private func openNewClient(with appInfo: SKTAppInfo, webview: WKWebView, completion: ((Result<Client, Error>) -> ())?) {
        let newClient = Client()
        
        do {
            let _ = try newClient.openWithAppInfo(appInfo: appInfo, webview: webview)
            completion?(.success(newClient))
        } catch let error {
            completion?(.failure(error))
        }
    }
    
    private func openDevice(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let verifiedJsonRpcObject = verified(jsonRPCObject: jsonRPCObject, webview: webview) else {
            return
        }
        
        let handle = verifiedJsonRpcObject.handle
        let responseId = verifiedJsonRpcObject.responseId
        
        guard let deviceGUID = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.guid.rawValue) as? String else {
            Utility.sendErrorResponse(withError: SKTResult.E_INVALIDPARAMETER,
                                     webView: webview,
                                     handle: handle,
                                     responseId: responseId)
            return
        }
        
        
        
        guard let client = Maraca.shared.getClient(for: handle) else {
            Utility.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: handle,
                                     responseId: responseId)
            return
        }
        
        func sendErrorForUnopenedDevice() {
            let errorResponseJsonRpc = Utility.constructErrorResponse(error: SKTResult.E_DEVICENOTOPEN,
                                                                     errorMessage: "There is no device with guid: \(deviceGUID) open at this time",
                                                                     handle: handle,
                                                                     responseId: responseId)
            
            client.replyToWebpage(with: errorResponseJsonRpc)
        }
        
        // Confirm that CaptureHelper has still opened the device
        
        // First, combine all CaptureHelperDevices and CaptureHelperDeviceManagers
        // into a single array
        let deviceManagers = Maraca.shared.capture.getDeviceManagers()
        let devices = Maraca.shared.capture.getDevices()
        
        let allCaptureDevices = deviceManagers + devices
        
        // Then filter through this combined array to find
        // the device with this GUID
        let filteredCaptureHelperDevices: [CaptureHelperDevice] = allCaptureDevices.filter ({ $0.deviceInfo.guid == deviceGUID })
        
        if let captureHelperDevice = filteredCaptureHelperDevices.first {
            
            // Finally, open this device
            client.open(captureHelperDevice: captureHelperDevice, jsonRPCObject: jsonRPCObject)
            
            // Change ownership of this device from the previously active client
            // if that client previously had ownership of this device.
            if let previousActiveClient = Maraca.shared.previousActiveClient {
                if let clientDevice = previousActiveClient.getClientDevice(for: captureHelperDevice) {
                    previousActiveClient.changeOwnership(forClientDeviceWith: clientDevice.handle, isOwned: false)
                }
            }
        
        } else {
            sendErrorForUnopenedDevice()
        }
    }
    
    private func close(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let verifiedJsonRpcObject = verified(jsonRPCObject: jsonRPCObject, webview: webview) else {
            return
        }
        
        let handle = verifiedJsonRpcObject.handle
        let responseId = verifiedJsonRpcObject.responseId
        
        // If the handle is for a Client, call the delegate
        // and remove from the list of clients.
        // If the client with this handle is the `activeClient`,
        // set it to nil
        if let client = Maraca.shared.getClient(for: handle) {
            
            client.close(responseId: responseId)
            delegate?.interpreter(self, didClose: client, with: handle)
            
        } else if let (client, _) = Maraca.shared.getClientDevice(for: handle) {
            
            // Close the ClientDevice with matching handle
            client.closeDevice(withHandle: handle, responseId: responseId)
            
        }
    }
    
    private func getProperty(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let verifiedJsonRpcObject = verified(jsonRPCObject: jsonRPCObject, webview: webview) else {
            return
        }
        
        let handle = verifiedJsonRpcObject.handle
        let responseId = verifiedJsonRpcObject.responseId
        
        let capturePropertyResult = Utility.constructSKTCaptureProperty(from: jsonRPCObject)
        
        switch capturePropertyResult {
        case .success(let captureProperty):
            if let client = Maraca.shared.getClient(for: handle) {
                
                client.getProperty(with: handle, responseId: responseId, property: captureProperty)
                
            } else if let (client, _) = Maraca.shared.getClientDevice(for: handle) {
                // Close the ClientDevice with matching handle
                client.getProperty(with: handle, responseId: responseId, property: captureProperty)
            }
            
        case .failure(_):
            // The values sent (property Id and property type) were invalid
            Utility.sendErrorResponse(withError: SKTResult.E_INVALIDPARAMETER,
                                     webView: webview,
                                     handle: nil,
                                     responseId: responseId)
            return
        }
        
    }
    
    private func setProperty(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let verifiedJsonRpcObject = verified(jsonRPCObject: jsonRPCObject, webview: webview) else {
            return
        }
        
        let handle = verifiedJsonRpcObject.handle
        let responseId = verifiedJsonRpcObject.responseId
        
        guard
            let propertyFromJson = verifiedJsonRpcObject.getParamsValue(for: MaracaConstants.Keys.property.rawValue) as? [String : Any]
            else {
            // The values sent were invalid or nil
            Utility.sendErrorResponse(withError: SKTResult.E_INVALIDPARAMETER,
                                     webView: webview,
                                     handle: handle,
                                     responseId: responseId)
            return
        }
        
        var client: Client?
        
        if let clientMatchingHandle = Maraca.shared.getClient(for: handle) {
            client = clientMatchingHandle
            
        } else if let (clientMatchingHandle, _) = Maraca.shared.getClientDevice(for: handle) {
            client = clientMatchingHandle
        }
        
        let capturePropertyResult = Utility.constructSKTCaptureProperty(from: jsonRPCObject)
        
        switch capturePropertyResult {
        case .success(let captureProperty):
            
            if let propertyValue = propertyFromJson[MaracaConstants.Keys.value.rawValue] {
                do {
                    try captureProperty.setPropertyValue(using: propertyValue)
                } catch let error {
                    
                    DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Error setting the value for SKTCaptureProperty: \(error)")
                    
                    // Send an error response Json back to the web page
                    // if an SKTCaptureProperty cannot be constructed
                    // from the dictionary sent from the webpage
                    let errorResponseJsonRpc = Utility.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                             errorMessage: error.localizedDescription,
                                                                             handle: handle,
                                                                             responseId: responseId)
                    
                    client?.replyToWebpage(with: errorResponseJsonRpc)
                }
            }
            
            client?.setProperty(with: handle, responseId: responseId, property: captureProperty)
            
        case .failure(let error):
            let errorJSONDictionary = Utility.constructErrorResponse(error: error)
            client?.replyToWebpage(with: errorJSONDictionary)
        }
    }
    
    
    private func verified(jsonRPCObject: JsonRPCObject, webview: WKWebView) -> VerifiedJSONRPCObject? {
        guard let handle = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.handle.rawValue) as? Int else {
            Utility.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: nil,
                                     responseId: nil)
            return nil
        }
        
        guard let responseId = jsonRPCObject.id as? Int else {
            let errorResponseJsonRpc = Utility.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                     errorMessage: "The id was not specified",
                                                                     handle: handle,
                                                                     responseId: nil)
            Maraca.shared.activeClient?.replyToWebpage(with: errorResponseJsonRpc)
            return nil
        }
        
        return VerifiedJSONRPCObject(handle: handle, responseId: responseId, jsonRPCObject: jsonRPCObject)
    }
}
