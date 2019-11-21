//
//  Maraca.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 11/18/19.
//

import Foundation
import SKTCapture
import WebKit.WKUserContentController

public final class Maraca: NSObject {
    
    // MARK: - Variables
    
    public private(set) weak var capture: CaptureHelper?
    
    private weak var delegate: MaracaDelegate?
    
    public static let shared = Maraca(capture: CaptureHelper.sharedInstance)
    
    public private(set) var clientsList: [ClientHandle : Client] = [:]
    
    public private(set) var activeClient: Client?
    public private(set) var activeClientIndexPath: IndexPath?
    
    public private(set) var previousActiveClient: Client?
    public private(set) var previousActiveClientIndexPath: IndexPath?
    
    // This will ensure that we always use the json rpc \
    // version that the web page specifies
    public private(set) static var jsonRpcVersion: String?
    
    
    
    
    private enum MaracaMessageHandlers: String, CaseIterable {
        case maracaSendJsonRpc
    }
    
    private enum CaptureJSMethod: String {
        case openClient = "openclient"
        case openDevice = "opendevice"
        case close = "close"
        case getProperty = "getproperty"
        case setProperty = "setproperty"
    }
    
    
    
    
    // MARK: - Initializers
    
    private init(capture: CaptureHelper) {
        super.init()
        self.capture = capture
    }
}








extension Maraca {
    
    public func setDelegate(to: MaracaDelegate) {
        delegate = to
    }
}









// MARK: - Public setters and getters

extension Maraca {
    
    public func activateClient(at indexPath: IndexPath) {
        let clientAtIndexPath = Array(clientsList.values)[indexPath.item]
        
        if activeClient != clientAtIndexPath {
            
            previousActiveClientIndexPath = activeClientIndexPath
            previousActiveClient = activeClient
            
            activeClientIndexPath = indexPath
            activeClient = clientAtIndexPath
            
            activeClient?.resume()
            self.capture?.pushDelegate(self)
        }
    }
    
    public func activateClient(_ client: Client) {
        guard let arrayElementIndex = Array(clientsList.values).firstIndex(of: client)
            else { return }
        previousActiveClientIndexPath = activeClientIndexPath
        previousActiveClient = activeClient
        
        activeClientIndexPath = IndexPath(item: Int(arrayElementIndex), section: 0)
        
        self.capture?.pushDelegate(self)
        
        // If there was an active client previously, and this previous client
        // is not the one that will be activated, then the resume() function
        // should be called, which is expected to resume all CaptureJS functions
        // (i.e. resend device arrivals, etc.)
        
        if activeClient != nil && activeClient?.handle != Array(clientsList.values)[arrayElementIndex].handle {
            activeClient = Array(clientsList.values)[arrayElementIndex]
            activeClient?.resume()
        } else {
            // Otherwise, just set the active client
            activeClient = Array(clientsList.values)[arrayElementIndex]
        }
    }
    
    public func activateClient(for url: URL) {
        
        guard let client = getClient(for: url.absoluteString) else {
            return
        }
        self.activateClient(client)
    }
    
    public func resignActiveClient() {
        activeClient?.suspend()
        activeClient = nil
        activeClientIndexPath = nil
    }
    
    public func closeAndDeleteClient(_ client: Client) {
        // If the client has opened a device, close the device(s). Otherwise, do nothing
        client.closeAllDevices()
        
        if activeClient == client {
            activeClient = nil
            activeClientIndexPath = nil
        }
        
        clientsList.removeValue(forKey: client.handle)
    }
    
    public func closeAndDeleteClients(_ clients: [Client]) {
        clients.forEach { closeAndDeleteClient($0) }
    }
    
    
    
    
    // Getters
    
    // Clients are mapped to a specific url, not a domain name
    // So there can be two different clients for these two urls:
    // http://www.socketmobile.com/products
    // http://www.socketmobile.com/products/scanners.html
    //
    // This function will return a client that has been opened
    // for this specific url
    public func getClient(for webpageURLString: String) -> Client? {
        guard let client = (Array(clientsList.values).filter { (client) -> Bool in
            return client.webpageURLString == webpageURLString
        }).first else {
            return nil
        }
        return client
    }
    
    // Will return a list of all clients that have been opened
    // by this WKWebView
    // This is intended to be used to closing all clients
    // that have been opened by a particular "tab"
    public func getClients(for webView: WKWebView) -> [Client]? {
        return (Array(clientsList.values).filter { (client) -> Bool in
            return client.webview == webView
        })
    }
}












// MARK: - WKScriptMessageHandler

extension Maraca {
    
    public func addMessageHandlers(to userContentController: WKUserContentController, scriptMessageHandler: WKScriptMessageHandler) {
        MaracaMessageHandlers.allCases.forEach { (messageHandler) in
            userContentController.add(LeakAvoider(delegate: scriptMessageHandler), name: messageHandler.rawValue)
        }
    }
    
    public func didReceiveCaptureJSMessage(message: WKScriptMessage) -> Bool {
        
        guard let messageBody = message.body as? String, let webview = message.webView else {
            return false
        }
        
        guard let messageHandler = MaracaMessageHandlers(rawValue: message.name) else {
            // Enum initializer is optional by default
            // If we don't unwrap, Xcode will complain
            // The initializer is optional because if it receives a `message.name` String that
            // was not specified in the enum, it will return nil.
            //
            // .... In other words, the web page is sending a Javascript message that we did not implement yet
            return false
        }
        
        switch messageHandler {
        case .maracaSendJsonRpc:
            
            guard let dictionary = Maraca.convertToDictionary(text: messageBody) else {
                return false
            }
            
            let jsonRPCObject = JsonRPCObject(dictionary: dictionary)
            Maraca.jsonRpcVersion = jsonRPCObject.jsonrpc
            
            guard
                let method = jsonRPCObject.method,
                let captureJSMethod = CaptureJSMethod(rawValue: method)
                else {
                    print("message body: \(messageBody)\n")
                    print("dictionary: \(dictionary)\n")
                    print("jsonRpcObject: \(jsonRPCObject)\n")
                    return false
            }
            
            switch captureJSMethod {
            case CaptureJSMethod.openClient:
                
                openClient(with: jsonRPCObject, webview: webview)
                
            case CaptureJSMethod.openDevice:
                
                openDevice(jsonRPCObject: jsonRPCObject, webview: webview)
                
            case CaptureJSMethod.close:
                
                close(jsonRPCObject: jsonRPCObject, webview: webview)
                
            case CaptureJSMethod.getProperty:
                
                getProperty(jsonRPCObject: jsonRPCObject, webview: webview)
                
            case CaptureJSMethod.setProperty:
                
                setProperty(jsonRPCObject: jsonRPCObject, webview: webview)
                
            }
        }
        
        return true
    }
}










// MARK: - Switch case functions

extension Maraca {
    
    private func openClient(with jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let appInfoDictionary = jsonRPCObject.getAppInfo() else { return }
        
        let appInfo = SKTAppInfo()
        appInfo.appID = appInfoDictionary[MaracaConstants.Keys.appId.rawValue] as? String
        appInfo.appKey = appInfoDictionary[MaracaConstants.Keys.appKey.rawValue] as? String
        appInfo.developerID = appInfoDictionary[MaracaConstants.Keys.developerId.rawValue] as? String
        
        openNewClient(with: appInfo, webview: webview) { [weak self] (result) in
            
            guard let strongSelf = self else {
                fatalError()
            }
            
            switch result {
            case .success(let client):
                let responseJsonRpc: [String: Any] = [
                    MaracaConstants.Keys.jsonrpc.rawValue:   jsonRPCObject.jsonrpc ?? "2.0",
                    // The spec says "transport-openclient" but the id is expected to be an integer
                    MaracaConstants.Keys.id.rawValue:        jsonRPCObject.id ?? "transport-openclient",
                    MaracaConstants.Keys.result.rawValue: [
                        MaracaConstants.Keys.handle.rawValue: client.handle
                    ]
                ]
                
                client.replyToWebpage(with: responseJsonRpc)
                
                strongSelf.activateClient(client)
                
                strongSelf.delegate?.maraca?(strongSelf, webviewDidOpenCaptureWith: client)
            case .failure(_):
                
                let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDAPPINFO,
                                                                         errorMessage: "The AppInfo parameters are invalid",
                                                                         handle: nil,
                                                                         responseId: jsonRPCObject.id as? Int)
                
                
                guard let jsonAsString = Maraca.convertJsonRpcToString(errorResponseJsonRpc) else { return }
                
                // Refer to replyJSonRpc and receiveJsonRPC functions
                // REceive used for when received decoded data
                // reply for when replying back to web page that you opened the client, set a property etc.
                
                var javascript = "window.maraca.replyJsonRpc('"
                javascript.write(jsonAsString)
                javascript.write("'); ")
                
                webview.evaluateJavaScript(javascript, completionHandler: { (object, error) in
                    if let error = error {
                        print("\nerror when calling \(javascript)")
                        print("Error: \(error)\n")
                    } else {
                        print("\nscript \(javascript) completed\n")
                    }
                })
                
            }
        }
    }
    
    private func openNewClient(with appInfo: SKTAppInfo, webview: WKWebView, completion: ((Result<Client, Error>) -> ())?) {
        let newClient = Client()
        
        do {
            let clientHandle: ClientHandle = try newClient.openWithAppInfo(appInfo: appInfo, webview: webview)
            clientsList[clientHandle] = newClient
            completion?(.success(newClient))
        } catch let error {
            completion?(.failure(error))
        }
    }
    
    private func openDevice(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let responseId = jsonRPCObject.id as? Int else {
            // The user may have still sent the client handle
            let clientHandle = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.handle.rawValue) as? Int
            
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                     errorMessage: "The id was not specified",
                                                                     handle: clientHandle,
                                                                     responseId: nil)
            activeClient?.replyToWebpage(with: errorResponseJsonRpc)
            return
        }
        
        guard let clientHandle = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.handle.rawValue) as? Int else {
            // The user may have still sent the responseId
            let responseId = jsonRPCObject.id as? Int
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: nil,
                                     responseId: responseId)
            return
        }
        
        guard let deviceGUID = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.guid.rawValue) as? String else {
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDPARAMETER,
                                     webView: webview,
                                     handle: clientHandle,
                                     responseId: responseId)
            return
        }
        
        
        
        guard let client = clientsList[clientHandle] else {
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: clientHandle,
                                     responseId: responseId)
            return
        }
        
        // Confirm that CaptureHelper has still opened the device
        guard let captureHelperDevice = capture?.getDevices().filter ({ $0.deviceInfo.guid == deviceGUID }).first else {
            
            // The web page is attempting to open a CaptureHelperDevice that
            // is no longer connected.
            // Reply to web page
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_DEVICENOTOPEN,
                                                                     errorMessage: "There is no device with guid: \(deviceGUID) open at this time",
                                                                     handle: client.handle,
                                                                     responseId: responseId)
            
            client.replyToWebpage(with: errorResponseJsonRpc)
            return
        }
        
        client.open(captureHelperDevice: captureHelperDevice, jsonRPCObject: jsonRPCObject)
        
        guard let clientDevice = previousActiveClient?.getClientDevice(for: captureHelperDevice) else {
            return
        }
        previousActiveClient?.changeOwnership(of: clientDevice, isOwned: false)
    }
    
    private func close(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let handle = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.handle.rawValue) as? Int else {
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: nil,
                                     responseId: nil)
            return
        }
        
        guard let responseId = jsonRPCObject.id as? Int else {
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                     errorMessage: "The id was not specified",
                                                                     handle: handle,
                                                                     responseId: nil)
            activeClient?.replyToWebpage(with: errorResponseJsonRpc)
            return
        }
        
        activeClient?.close(handle: handle, responseId: responseId)
        
        // If the handle is for a Client, call the delegate
        // and remove from the list of clients.
        // If the client with this handle is the `activeClient`,
        // set it to nil
        if let client = clientsList[handle] {
            delegate?.maraca?(self, webviewDidCloseCaptureWith: client)
            if activeClient == client {
                activeClient = nil
                activeClientIndexPath = nil
            }
            clientsList.removeValue(forKey: handle)
        }
    }
    
    private func getProperty(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let handle = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.handle.rawValue) as? Int else {
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: nil,
                                     responseId: nil)
            return
        }
        
        guard let responseId = jsonRPCObject.id as? Int else {
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                     errorMessage: "The id was not specified",
                                                                     handle: handle,
                                                                     responseId: nil)
            activeClient?.replyToWebpage(with: errorResponseJsonRpc)
            return
        }
        
        guard let captureProperty = constructSKTCaptureProperty(from: jsonRPCObject) else {
            // The values sent (property Id and property type) were invalid
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDPARAMETER,
                                     webView: webview,
                                     handle: nil,
                                     responseId: responseId)
            return
        }
        activeClient?.getProperty(with: handle, responseId: responseId, property: captureProperty)
    }
    
    private func setProperty(jsonRPCObject: JsonRPCObject, webview: WKWebView) {
        
        guard let handle = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.handle.rawValue) as? Int else {
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: nil,
                                     responseId: nil)
            return
        }
        
        guard let responseId = jsonRPCObject.id as? Int else {
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                     errorMessage: "The id was not specified",
                                                                     handle: handle,
                                                                     responseId: nil)
            activeClient?.replyToWebpage(with: errorResponseJsonRpc)
            return
        }
        
        guard
            let propertyFromJson = jsonRPCObject.getParamsValue(for: MaracaConstants.Keys.property.rawValue) as? [String : Any],
            let captureProperty = constructSKTCaptureProperty(from: jsonRPCObject)
        else {
            // The values sent were invalid or nil
            Maraca.sendErrorResponse(withError: SKTResult.E_INVALIDPARAMETER,
                                     webView: webview,
                                     handle: nil,
                                     responseId: responseId)
            return
        }
        
        if let propertyValue = propertyFromJson[MaracaConstants.Keys.value.rawValue] {
            do  {
                try captureProperty.setPropertyValue(using: propertyValue)
            } catch let error {
                
                print("Error setting the value for SKTCaptureProperty: \(error)")
                
                // Send an error response Json back to the web page
                // if an SKTCaptureProperty cannot be constructed
                // from the dictionary sent from the webpage
                let errorResponseJsonRpc = Maraca.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                         errorMessage: error.localizedDescription,
                                                                         handle: activeClient?.handle,
                                                                         responseId: responseId)
                
                activeClient?.replyToWebpage(with: errorResponseJsonRpc)
            }
        }
        
        activeClient?.setProperty(with: handle, responseId: responseId, property: captureProperty)
        
    }
}







// MARK: - CaptureHelper delegation

extension Maraca: CaptureHelperAllDelegate {
    
    public func didReceiveError(_ error: SKTResult) {
        
        guard let activeClient = activeClient else { return }
        
        // TODO
        // There is no information associated with the error
        let errorResponseJsonRpc = Maraca.constructErrorResponse(error: error,
                                                                 errorMessage: "Some kind of error specific message",
                                                                 handle: activeClient.handle,
                                                                 responseId: nil)
        
        activeClient.notifyWebpage(with: errorResponseJsonRpc)
        
    }
    
    public func didNotifyArrivalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
        
        guard let activeClient = activeClient else { return }
        
        guard result == SKTResult.E_NOERROR else {
            
            let errorMessage = "There was an error with arrival of the Socket Mobile device: \(String(describing: device.deviceInfo.name)). Error: \(result)"
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: result,
                                                                     errorMessage: errorMessage,
                                                                     handle: activeClient.handle,
                                                                     responseId: nil)
            
            activeClient.notifyWebpage(with: errorResponseJsonRpc)
            return
        }
        
        guard
            let deviceName = device.deviceInfo.name,
            let deviceGuid = device.deviceInfo.guid,
            let clientHandle = activeClient.handle else { return }
        
        // Send the deviceArrival to the web app along with its guid
        // The web app may ignore this, but when it is ready to open
        // the device, it will send the guid back to Maraca
        // in order to open this device.
        
        let jsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? "2.0",
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : 1,
                    MaracaConstants.Keys.type.rawValue : 6,
                    MaracaConstants.Keys.value.rawValue : [
                        MaracaConstants.Keys.guid.rawValue : deviceGuid,
                        MaracaConstants.Keys.name.rawValue : deviceName,
                        MaracaConstants.Keys.type.rawValue : device.deviceInfo.deviceType.rawValue
                    ]
                ]
            ]
        ]
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    public func didNotifyRemovalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
        
        guard let activeClient = activeClient else { return }
        
        guard result == SKTResult.E_NOERROR else {
            
            let errorMessage = "There was an error with removal of the Socket Mobile device: \(String(describing: device.deviceInfo.name)). Error: \(result)"
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: result,
                                                                     errorMessage: errorMessage,
                                                                     handle: activeClient.handle,
                                                                     responseId: nil)
            
            activeClient.notifyWebpage(with: errorResponseJsonRpc)
            return
        }
        
        guard
            let deviceName = device.deviceInfo.name,
            let deviceGuid = device.deviceInfo.guid,
            let clientHandle = activeClient.handle else { return }
        
        let jsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? "2.0",
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : 2,
                    MaracaConstants.Keys.type.rawValue : 6,
                    MaracaConstants.Keys.value.rawValue : [
                        MaracaConstants.Keys.guid.rawValue : deviceGuid,
                        MaracaConstants.Keys.name.rawValue : deviceName,
                        MaracaConstants.Keys.type.rawValue : device.deviceInfo.deviceType.rawValue
                    ]
                ]
            ]
        ]
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    public func didChangePowerState(_ powerState: SKTCapturePowerState, forDevice device: CaptureHelperDevice) {
        
        guard
            let activeClient = activeClient,
            let clientHandle = activeClient.handle
        else { return }
        
        let jsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? "2.0",
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : 6,
                    MaracaConstants.Keys.type.rawValue : 5,
                    MaracaConstants.Keys.value.rawValue : powerState.rawValue
                ]
            ]
        ]
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    public func didChangeBatteryLevel(_ batteryLevel: Int, forDevice device: CaptureHelperDevice) {
        
        guard
            let activeClient = activeClient,
            let clientHandle = activeClient.handle
        else { return }
        
        let jsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? "2.0",
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : 8,
                    MaracaConstants.Keys.type.rawValue : 3,
                    MaracaConstants.Keys.value.rawValue : batteryLevel
                ]
            ]
        ]
        
        activeClient.notifyWebpage(with: jsonRpc)
    
    }
    
    public func didReceiveDecodedData(_ decodedData: SKTCaptureDecodedData?, fromDevice device: CaptureHelperDevice, withResult result: SKTResult) {
        
        guard
            let activeClient = activeClient,
            let clientHandle = activeClient.handle
        else { return }
        
        guard result == SKTResult.E_NOERROR else {
            
            let errorResponseJsonRpc = Maraca.constructErrorResponse(error: result,
                                                                     errorMessage: "There was an error receiving decoded data from the Socket Mobile device: \(String(describing: device.deviceInfo.name)). Error: \(result)",
                                                                     handle: activeClient.handle,
                                                                     responseId: nil)
            
            activeClient.notifyWebpage(with: errorResponseJsonRpc)
            return
        }
        
        guard
            let deviceGuid = device.deviceInfo.guid,
            let dataFromDecodedDataStruct = decodedData?.decodedData,
            let dataSourceName = decodedData?.dataSourceName,
            let dataSourceId = decodedData?.dataSourceID.rawValue
            else { return }
        
        
        
        
        // Confirm that the ClientDevice has been previously opened
        // by the active client
        
        guard activeClient.hasPreviouslyOpenedDevice(with: deviceGuid) else {
            return
        }
        
        let dataAsIntegerArray: [UInt8] = [UInt8](dataFromDecodedDataStruct)
        
        let jsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? "2.0",
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : 5,
                    MaracaConstants.Keys.type.rawValue : 5,
                    MaracaConstants.Keys.value.rawValue : [
                        MaracaConstants.Keys.data.rawValue : dataAsIntegerArray,
                        MaracaConstants.Keys.id.rawValue : dataSourceId,
                        MaracaConstants.Keys.name.rawValue : dataSourceName
                    ]
                ]
            ]
        ]
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    public func didChangeButtonsState(_ buttonsState: SKTCaptureButtonsState, forDevice device: CaptureHelperDevice) {
        
        guard
            let activeClient = activeClient,
            let clientHandle = activeClient.handle
        else { return }
        
        let jsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? "2.0",
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : 7,
                    MaracaConstants.Keys.type.rawValue : 1,
                    MaracaConstants.Keys.value.rawValue : buttonsState.rawValue,
                    
                ]
            ]
        ]
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
}


















// MARK: - Utility functions

extension Maraca {
    
    public static func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    public static func convertJsonRpcToString(_ jsonRpc: [String: Any]) -> String? {
        do {
            let jsonAsData = try JSONSerialization.data(withJSONObject: jsonRpc, options: [])
            return String(data: jsonAsData, encoding: String.Encoding.ascii)
        } catch let error {
            print("Error converting JsonRpc object to String: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func constructSKTCaptureProperty(from jsonRPCObject: JsonRPCObject) -> SKTCaptureProperty? {
        
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
    
    
    
    
    
    
    
    
    /// construct a json dictionary with information based on the SKTResult
    /// passed in. Then send the dictionary to the web page that the WKWebView
    /// is displaying
    public static func sendErrorResponse(withError error: SKTResult, webView: WKWebView, handle: Int?, responseId: Int?) {
        
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
    
    public static func constructErrorResponse(error: SKTResult, errorMessage: String, handle: Int?, responseId: Int?) -> [String: Any] {
        
        let responseJsonRpc: [String: Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue:  Maraca.jsonRpcVersion ?? "2.0",
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
