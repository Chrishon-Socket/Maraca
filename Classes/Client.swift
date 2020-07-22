//
//  Client.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 11/18/19.
//

import Foundation
import SKTCapture
import WebKit.WKWebView

public class Client: NSObject, ClientReceiverProtocol {
    
    // MARK: - Variables
    
    internal private(set) var handle: ClientHandle!
    
    // Used to denote which client currently has active
    // ownership of BLE devices
    internal let ownershipId: String = UUID().uuidString
    
    internal static var disownedBlankId: String {
        // If this client does not have ownership, a
        // "blank" UUID string will be sent to the web
        // app using CaptureJS
        return "00000000-0000-0000-0000-000000000000"
    }
    
    private var appInfo: SKTAppInfo?
    
    // This is used to identify/retrieve a client with a webview
    internal private(set) var webpageURLString: String?
    
    // This is used to send data back to the current web page
    internal private(set) weak var webview: WKWebView?
    
    internal private(set) var didOpenCapture: Bool = false
    
    // Keep track of the capture helper devices that this client has opened.
    internal private(set) var openedDevices: [ClientDeviceHandle : ClientDevice] = [:]
}









// MARK: - Open / Close

extension Client {
    
    @discardableResult internal func openWithAppInfo(appInfo: SKTAppInfo, webview: WKWebView) throws -> ClientHandle {
        // => add new Client Instance to clients list in Maraca
        // => AppInfo Verify ==> TRUE
        // => send device Arrivals if devices connected
        // => return a handle
        
        guard appInfo.verify(withBundleId: appInfo.appID) == true else {
            throw MaracaError.invalidAppInfo("The AppInfo parameters are invalid")
        }
        
        self.appInfo = appInfo
        didOpenCapture = true
        
        self.webview = webview
        self.webpageURLString = webview.url?.absoluteString
        
        handle = Int(Date().timeIntervalSince1970)
        
        guard didOpenCapture == false else {
            return handle
        }
        
        return handle
    }
    
    internal func open(captureHelperDevice: CaptureHelperDevice, jsonRPCObject: JsonRPCObject) {
        let clientDevice = ClientDevice(captureHelperDevice: captureHelperDevice)
        openedDevices[clientDevice.handle] = clientDevice
        
        let responseJsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue:       jsonRPCObject.jsonrpc ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.id.rawValue:            jsonRPCObject.id ?? 2,
            MaracaConstants.Keys.result.rawValue: [
                MaracaConstants.Keys.handle.rawValue: clientDevice.handle
            ]
        ]
        
        replyToWebpage(with: responseJsonRpc)
        
        changeOwnership(forClientDeviceWith: clientDevice.handle, isOwned: true)
    }
    
    internal func close(handle: Int, responseId: Int) {
        if handle == self.handle {
            closeAllDevices()
        } else {
            closeDevice(with: handle, responseId: responseId)
        }
        
        let responseJsonRpc: [String:  Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue: Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.id.rawValue: responseId,
            MaracaConstants.Keys.result.rawValue: 0
        ]
        
        replyToWebpage(with: responseJsonRpc)
    }
    
    internal func closeAllDevices() {
        openedDevices.removeAll()
    }
    
    internal func closeDevice(with handle: ClientDeviceHandle, responseId: Int) {
        guard let _ = openedDevices[handle] else {
            guard let webview = webview else {
                // The webview should not be nil
                fatalError("The Client must have been created without calling `openWithAppInfo`")
            }
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: handle,
                                     responseId: responseId)
            return
        }
            
        openedDevices.removeValue(forKey: handle)
    }
    
    internal func changeOwnership(forClientDeviceWith handle: ClientDeviceHandle, isOwned: Bool) {
        
        let responseJson: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue: Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.result.rawValue: [
                MaracaConstants.Keys.handle.rawValue: handle,
                MaracaConstants.Keys.event.rawValue: [
                    MaracaConstants.Keys.id.rawValue: SKTCaptureEventID.deviceOwnership.rawValue,
                    MaracaConstants.Keys.type.rawValue: SKTCaptureEventDataType.string.rawValue,
                    MaracaConstants.Keys.value.rawValue: (isOwned ? self.ownershipId : Client.disownedBlankId)
                ]
            ]
        ]
        notifyWebpage(with: responseJson)
    }
}










// MARK: - Get / Set property

extension Client {
    
    internal func getProperty(with handle: Int, responseId: Int, property: SKTCaptureProperty) {
        
        if handle == self.handle {
            getProperty(property: property, responseId: responseId) { (result) in
                self.replyToWebpage(with: resultDictionary(result))
            }
        } else if let _ = openedDevices[handle] {
            openedDevices[handle]?.getProperty(property: property, responseId: responseId, completion: { (result) in
                self.replyToWebpage(with: resultDictionary(result))
            })
        } else {
            
            let errorMessage = "There is no client or device with the specified handle. The device may have been recently closed"
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDHANDLE,
                                                                     errorMessage: errorMessage,
                                                                     handle: handle,
                                                                     responseId: responseId)
            DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - error response json rpc: \(errorResponseJsonRpc)")
            self.replyToWebpage(with: errorResponseJsonRpc)
        }
    }
    
    internal func setProperty(with handle: Int, responseId: Int, property: SKTCaptureProperty) {
        
        if handle == self.handle {
            // TODO
            // Will this affect other Clients?
            // Each Client instance uses a single CaptureHelper
            // shared instance
            // So setting a property to a particular value might
            // affect other Clients that don't want this.
            setProperty(property: property, responseId: responseId) { (result) in
                self.replyToWebpage(with: resultDictionary(result))
            }
        } else if let _ = openedDevices[handle] {
            openedDevices[handle]?.setProperty(property: property, responseId: responseId, completion: { (result) in
                self.replyToWebpage(with: resultDictionary(result))
            })
        } else {
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDHANDLE,
                                                                     errorMessage: "There is no client or device with the specified handle. The device may have been recently closed",
                                                                     handle: handle,
                                                                     responseId: responseId)
            self.replyToWebpage(with: errorResponseJsonRpc)
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    internal func getProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler) {
        Maraca.shared.capture?.getProperty(property) { (result, property) in
            
            guard result == .E_NOERROR else {
                
                let errorResponseJsonRpc = Maraca.constructErrorResponse(error: result,
                                                                         errorMessage: "There was an error with getting property from Capture. Error: \(result)",
                                                                         handle: self.handle,
                                                                         responseId: responseId)
                
                completion(.failure(ErrorResponse(json: errorResponseJsonRpc)))
                return
            }
            
            // Used a different name to differentiate between the three
            guard let unwrappedProperty = property else {
                // TODO
                // Return with some kind of error response instead.
                // But if the result != E_NOERROR, this will not be reached anyway.
                fatalError("This is an issue with CaptureHelper if the SKTCaptureProperty is nil")
            }
            
            do {
                let jsonFromGetProperty = try unwrappedProperty.jsonFromGetProperty(with: responseId)
                completion(.success(jsonFromGetProperty))
            } catch let error {
                DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Error converting SKTCaptureProperty to a dictionary: \(error)")
                
                // Send an error response Json back to the web page
                // if a dictionary cannot be constructed from
                // the resulting SKTCaptureProperty
                let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                         errorMessage: error.localizedDescription,
                                                                         handle: self.handle,
                                                                         responseId: responseId)
                
                completion(.failure(ErrorResponse(json: errorResponseJsonRpc)))
            }
        }
    }
    
    internal func setProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler) {
        
        Maraca.shared.capture?.setProperty(property) { (result, property) in
            
            guard result == .E_NOERROR else {
                
                let errorResponseJsonRpc = Maraca.constructErrorResponse(error: result,
                                                                         errorMessage: "There was an error with setting property. Error: \(result)",
                                                                         handle: self.handle,
                                                                         responseId: responseId)
                
                completion(.failure(ErrorResponse(json: errorResponseJsonRpc)))
                return
            }
            
            let jsonRpc: [String : Any] = [
                MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
                MaracaConstants.Keys.id.rawValue : responseId,
                MaracaConstants.Keys.result.rawValue: [
                    MaracaConstants.Keys.handle.rawValue : self.handle
                    // We might send the property back as well.
                ]
            ]
            
            completion(.success(jsonRpc))
        }
    }
    
}








// MARK: - Utility functions

extension Client {
    
    internal func hasPreviouslyOpenedDevice(with deviceGuid: String) -> Bool {
        return Array(openedDevices.values).filter { return $0.guid == deviceGuid }.count > 0
    }
    
    internal func getClientDevice(for device: CaptureHelperDevice) -> ClientDevice? {
        return Array(openedDevices.values).filter { return $0.guid == device.deviceInfo.guid }.first
    }
    
    internal func resume() {
        guard didOpenCapture == true else {
            fatalError()
        }
        
        
//        Send device arrival?
        
        // TODO
        // This has unintended issues and should not be used.
        // The purpose was to stop all Javascript, UI animations, events, etc.
        // from the web page when the active tab was switched
        //        webview?.configuration.preferences.javaScriptEnabled = true
        //        print("did resume client with handle: \(handle)")
        
        // TODO
        // Send device arrivals, etc.
    }
    
    internal func suspend() {
        guard didOpenCapture == true else {
            fatalError()
        }
        
//        Send device removal?
        
        // TODO
        // This has unintended issues and should not be used.
        // The purpose was to stop all Javascript, UI animations, events, etc.
        // from the web page when the active tab was switched
        //        webview?.configuration.preferences.javaScriptEnabled = false
        //        print("did suspend client with handle: \(handle)")
    }
    
    // For responding back to a web page that has
    // opened a capture with a client, etc.
    internal func replyToWebpage(with jsonRpc: [String: Any]) {
        sendJsonRpcToWebpage(jsonRpc: jsonRpc, javascriptFunctionName: "window.maraca.replyJsonRpc('")
    }
    
    // For sending information to the web page
    internal func notifyWebpage(with jsonRpc: [String: Any]) {
        sendJsonRpcToWebpage(jsonRpc: jsonRpc, javascriptFunctionName: "window.maraca.receiveJsonRpc('")
    }
    
    private func sendJsonRpcToWebpage(jsonRpc: [String: Any], javascriptFunctionName: String) {
        
        guard let jsonAsString = Maraca.convertJsonRpcToString(jsonRpc) else { return }
        
        // Refer to replyJSonRpc and receiveJsonRPC functions
        // REceive used for when received decoded data
        // reply for when replying back to web page that you opened the client, set a property etc.
        
        var javascript = javascriptFunctionName
        javascript.write(jsonAsString)
        javascript.write("'); ")
        
        guard webview?.url?.absoluteString == webpageURLString else {
            // Confirm that the current active client is still the
            // one being used with the web page that is currently displayed
            // in the WKWebView
            // This should not happen since the active client is updated every
            // time the WKWebView loads a new page, but just to be sure we catch any bugs...
            fatalError("This client is attempting to send data to the wrong web page")
        }
        
        webview?.evaluateJavaScript(javascript, completionHandler: { (object, error) in
            if let error = error {
                DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - error evaluating javascript expression: \(javascript). Error: \(error)\n")
            } else {
                DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Success evaluating javascript expression: \(javascript)\n")
            }
        })
    }
}
