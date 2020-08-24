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
    
    public private(set) weak var capture: CaptureHelper!
    
    private var remainingOpenCaptureRetries: Int = 2
    
    private weak var delegate: MaracaDelegate?
    
    public static let shared = Maraca(capture: CaptureHelper.sharedInstance)
    
    public private(set) var clientsList: [ClientHandle : Client] = [:]
    
    public private(set) var activeClient: Client?
    public private(set) var previousActiveClient: Client?
    
    // This will ensure that we always use the json rpc \
    // version that the web page specifies
    public private(set) static var jsonRpcVersion: String?
    
    public static let defaultJsonRpcVersion: String = "2.0"
    
    
    
    public private(set) var webViewConfiguration = WKWebViewConfiguration()
    private var userContentController = WKUserContentController()
    
    internal enum MaracaMessageHandlers: String, CaseIterable {
        case maracaSendJsonRpc
    }
    
    internal enum CaptureJSMethod: String {
        case openClient = "openclient"
        case openDevice = "opendevice"
        case close = "close"
        case getProperty = "getproperty"
        case setProperty = "setproperty"
    }
    
    private lazy var activeClientManager = ActiveClientManager(delegate: self)
    
    private lazy var javascriptInterpreter = JavascriptMessageInterpreter(delegate: self)
    
    
    
    // MARK: - Initializers (PRIVATE / Singleton)
    
    private init(capture: CaptureHelper) {
        super.init()
        self.capture = capture
    }
}







// MARK: - Setup Functions

extension Maraca {
    
    /// Determines whether debug messages will be logged
    /// to the DebugLogger object
    /// - Parameters:
    ///   - isActivated: Boolean value that, when set to true will save debug messages to the DebugLogger. False by default if unused
    @discardableResult
    public func setDebugMode(isActivated: Bool) -> Maraca {
        DebugLogger.shared.toggleDebug(isActivated: isActivated)
        return self
    }
    
    @discardableResult
    public func injectCustomJavascript(mainBundle: Bundle, javascriptFileNames: [String]) -> Maraca {
        
        if let applicationDisplayName = mainBundle.displayName {
            webViewConfiguration.applicationNameForUserAgent = applicationDisplayName
        }
        
        let javascriptFileExtension = "js"
        
        for fileName in javascriptFileNames {
            guard let pathForResource = mainBundle.path(forResource: fileName, ofType: javascriptFileExtension) else {
                continue
            }
            if let contentsOfJavascriptFile = try? String(contentsOfFile: pathForResource, encoding: String.Encoding.utf8) {
                
                let userScript = WKUserScript(source: contentsOfJavascriptFile, injectionTime: WKUserScriptInjectionTime.atDocumentEnd, forMainFrameOnly:true)
                userContentController.addUserScript(userScript)
            }
        }
        
        return self
    }
    
    @discardableResult
    public func observeJavascriptMessageHandlers(_ customMessageHandlers: [String]? = nil) -> Maraca {
        
        // wire the user content controller to this view controller and to the webView config
        userContentController.add(LeakAvoider(delegate: self), name: "observe")
            
        // Observe OPTIONAL custom message handlers that user sends
        customMessageHandlers?.forEach { (messageHandlerString) in
            userContentController.add(LeakAvoider(delegate: self), name: messageHandlerString)
        }
        
        // Observe Maraca-specific message handlers such as "open client", etc.
        MaracaMessageHandlers.allCases.forEach { (messageHandler) in
            userContentController.add(LeakAvoider(delegate: self), name: messageHandler.rawValue)
        }
        
        webViewConfiguration.userContentController = userContentController
        
        return self
    }
    
    @discardableResult
    public func setDelegate(to: MaracaDelegate) -> Maraca {
        self.delegate = to
        return self
    }
    
    public func begin(withAppKey appKey: String, appId: String, developerId: String, completion: ((SKTResult) -> ())? = nil) {
        
        let AppInfo = SKTAppInfo()
        AppInfo.appKey = appKey
        AppInfo.appID = appId
        AppInfo.developerID = developerId
        
        capture.dispatchQueue = DispatchQueue.main
        capture.openWithAppInfo(AppInfo) { [weak self] (result) in
            guard let strongSelf = self else { return }
            DebugLogger.shared.addDebugMessage("\(String(describing: type(of: strongSelf))) - Result of Capture initialization: \(result.rawValue)")
            
            if result == SKTResult.E_NOERROR {
                completion?(result)
            } else {

                if strongSelf.remainingOpenCaptureRetries == 0 {

                    // Display an alert to the user to restart the app
                    // if attempts to open capture have failed twice

                    // What should we do here in case of this issue?
                    // This is a SKTCapture-specific error
                    completion?(result)
                    
                } else {

                    // Attempt to open capture again
                    DebugLogger.shared.addDebugMessage("\(String(describing: type(of: self))) - Failed to open capture. attempting again...\n")
                    strongSelf.remainingOpenCaptureRetries -= 1
                    strongSelf.begin(withAppKey: appKey, appId: appId, developerId: developerId, completion: completion)
                }
            }
        }
    }
    
    public func stop(_ completion: ((Bool) -> ())?) {
        capture.closeWithCompletionHandler({ (result) in
            if result == SKTResult.E_NOERROR {
                completion?(true)
            } else {
                
                // What should we do here in case of this issue?
                // This is a SKTCapture-specific error
                completion?(false)
            }
        })
    }
}









// MARK: - Public setters and getters

extension Maraca {
    
    public func activateClient(_ client: Client) {
        guard let selectedClientIndex = Array(clientsList.values).firstIndex(of: client) else {
            return
        }
        
        previousActiveClient = activeClient
        activeClient?.suspend()
        activeClient = Array(clientsList.values)[selectedClientIndex]
        
        assumeCaptureDelegate()
        
        guard let activeClient = activeClient else {
            return
        }
        
        activeClientManager.resendDeviceArrivalEvents(for: activeClient)
        
    }
    
    public func activateClient(for url: URL) {
        
        guard let client = getClient(for: url.absoluteString) else {
            return
        }
        self.activateClient(client)
    }
    
    public func resignActiveClient() {
        previousActiveClient = activeClient
        activeClient?.suspend()
        activeClient = nil
    }
    
    public func closeAndDeleteClient(_ client: Client) {
        // If the client has opened a device, close the device(s). Otherwise, do nothing
        client.closeAllDevices()
        
        if activeClient == client {
            activeClient = nil
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
    
    internal func getClient(for handle: ClientHandle) -> Client? {
        return Maraca.shared.clientsList[handle]
    }
    
    internal func getClientDevice(for handle: ClientDeviceHandle) -> (Client, ClientDevice)? {
        // Returns a ClientDevice with the matching handle, and the Client that has opened it
        for (_, client) in Maraca.shared.clientsList {
            if let clientDevice = client.openedDevices[handle] {
                return (client, clientDevice)
            }
        }
        return nil
    }
}












// MARK: - WKScriptMessageHandler

extension Maraca: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        if javascriptInterpreter.didReceiveCaptureJSMessage(message: message) {
            return
        } else {
            
            // Otherwise, the developer can handle their own message handlers
            // (The ones that were passed into `observeJavascriptMessageHandlers(<#T##customMessageHandlers: [String]##[String]#>)`
            delegate?.maraca(self, didReceive: message)
        }
    }
}








// MARK: - Utility functions

extension Maraca {
    
    /// Re-assumes SKTCapture layer delegate
    public func assumeCaptureDelegate() {
        capture.pushDelegate(activeClientManager.captureDelegate)
    }
    
    /// Resigns SKTCapture layer delegate to desired receiver
    public func resignCaptureDelegate(to: CaptureHelperAllDelegate) {
        capture.pushDelegate(to)
    }
}











// MARK: - ActiveClientManagerDelegate

extension Maraca: ActiveClientManagerDelegate {
    
    func activeClient(_ manager: ActiveClientManager, didNotifyArrivalFor device: CaptureHelperDevice, result: SKTResult) {
        delegate?.maraca?(self, didNotifyArrivalFor: device, result: result)
    }
    
    func activeClient(_ manager: ActiveClientManager, didNotifyRemovalFor device: CaptureHelperDevice, result: SKTResult) {
        delegate?.maraca?(self, didNotifyRemovalFor: device, result: result)
    }
    
    func activeClient(_ manager: ActiveClientManager, batteryLevelDidChange value: Int, for device: CaptureHelperDevice) {
        delegate?.maraca?(self, batteryLevelDidChange: value, for: device)
    }
}










// MARK: - JavascriptMessageInterpreterDelegate

extension Maraca: JavascriptMessageInterpreterDelegate {
    
    func interpreter(_ interpreter: JavascriptMessageInterpreter, didReceiveJSONRPC version: String) {
        Maraca.jsonRpcVersion = version
    }
    
    func interpreter(_ interpreter: JavascriptMessageInterpreter, didOpen client: Client, webview: WKWebView) {
        guard let clientHandle = client.handle else {
            Utility.sendErrorResponse(withError: SKTResult.E_INVALIDHANDLE,
                                     webView: webview,
                                     handle: nil,
                                     responseId: nil)
            return
        }
        
        clientsList[clientHandle] = client
        
        activateClient(client)
        
        delegate?.maraca?(self, webviewDidOpenCaptureWith: client)
    }
    
    func interpreter(_ interpreter: JavascriptMessageInterpreter, didClose client: Client, with handle: ClientHandle) {
        closeAndDeleteClient(client)
        delegate?.maraca?(self, webviewDidCloseCaptureWith: client)
    }
    
}
