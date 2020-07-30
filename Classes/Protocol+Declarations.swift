//
//  Protocol+Declarations.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 11/18/19.
//

import Foundation
import SKTCapture
import WebKit.WKScriptMessage
// This file maintains all of the protocols, typealiases,
// enums and utility structs used within Maraca


// MARK: - MaracaDelegate

/// Public optional delegate used by Maraca class.
@objc public protocol MaracaDelegate: class {
    
    /**
    Notifies the delegate that a CaptureHelper device has been connected
    Use this to refresh UI in iOS application
     
    Even if using Maraca and SKTCapture simultaneously, this function will
    only be called once, depending on which entity is set as the Capture delegate.
     
     - Parameters:
        - maraca: The Maraca object
        - device: Wrapper for the actual Bluetooth device
        - result: The result and/or possible error code for the notification
     */
    @objc optional func maraca(_ maraca: Maraca, didNotifyArrivalFor device: CaptureHelperDevice, result: SKTResult)
    
    /**
     Notifies the delegate that a CaptureHelper device has been disconnected
     Use this to refresh UI in iOS application
     
     Even if using Maraca and SKTCapture simultaneously, this function will
     only be called once, depending on which entity is set as the Capture delegate.
     
     - Parameters:
         - maraca: The Maraca object
         - device: Wrapper for the actual Bluetooth device
         - result: The result and/or possible error code for the notification
     */
    @objc optional func maraca(_ maraca: Maraca, didNotifyRemovalFor device: CaptureHelperDevice, result: SKTResult)
    
    /**
     Notifies the delegate that the battery level of aa CaptureHelperDevice has changed
     Use this to refresh UI in iOS application
     
     Even if using Maraca and SKTCapture simultaneously, this function will
     only be called once, depending on which entity is set as the Capture delegate.
     
     - Parameters:
         - maraca: The Maraca object
         - value: Current battery level for the device
         - device: Wrapper for the actual Bluetooth device
     */
    @objc optional func maraca(_ maraca: Maraca, batteryLevelDidChange value: Int, for device: CaptureHelperDevice)
    
    /**
     Notifies the delegate that a new Client (which represents a web application using CaptureJS)
     has been opened
     
     - Parameters:
         - maraca: The Maraca object
         - client: Object used to represent the current web application page using CaptureJS
     */
    @objc optional func maraca(_ maraca: Maraca, webviewDidOpenCaptureWith client: Client)
    
    /**
     Notifies the delegate that a Client (which represents a web application using CaptureJS)
     has been closed
     
     - Parameters:
         - maraca: The Maraca object
         - client: Object used to represent the current web application page using CaptureJS
     */
    @objc optional func maraca(_ maraca: Maraca, webviewDidCloseCaptureWith client: Client)
    
    /**
     Notifies the delegate that a script message has been received
     that is not related to Maraca.
     
     This delegate function is only called if custom Javascript Message Handlers
     are provided during initialization in this function:
     `observeJavascriptMessageHandlers(_ customMessageHandlers: [String]? = nil)`
     
     - Parameters:
         - maraca: The Maraca object
         - scriptMessage: A WKScriptMessage object contains information about a message sent from a webpage.
     */
    func maraca(_ maraca: Maraca, didReceive scriptMessage: WKScriptMessage)
    
}




internal extension Bundle {
    // Name of the app - title under the icon.
    var displayName: String? {
            return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

/// Dictionary containing key-value pairs from incoming JSON responses or outgoing requests
public typealias JSONDictionary = [String: Any]

/// Result of get or set requests. Returns JSON dictionary for success and error for failure
internal typealias ResultResponse = Result<JSONDictionary, ErrorResponse>



/// Anonymous closure that takes the ResultResponse as a parameter
/// and returns a json (whether for failure or success)
internal let resultDictionary: (ResultResponse) -> JSONDictionary = { (result) in
    switch result {
    case .failure(let errorResponse):
        return errorResponse.json
    case .success(let successResponseJsonRpc):
        return successResponseJsonRpc
    }
}





/// Typealias for common completion handler
internal typealias ClientReceiverCompletionHandler = (ResultResponse) -> ()

/// Protocol adopted by both the Client and ClientDevice objects for performing get and set requests
internal protocol ClientReceiverProtocol {
    /**
     Performs get property request and returns response in a JSONDictionary if successful or an ErrorResponse otherwise
     
     - Parameters:
        - property: The `SKTCaptureProperty` to be requested
        - responseId: The unique identifier from the web application making the request
        - completion: Completion handler for returning result of get request
     */
    func getProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler)
    
    /**
    Performs set property request and returns response in a JSONDictionary if successful or an ErrorResponse otherwise
    
    - Parameters:
       - property: The `SKTCaptureProperty` to be requested
       - responseId: The unique identifier from the web application making the request
       - completion: Completion handler for returning result of set request
    */
    func setProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler)
}






/// Protocol adopted by ErrorResponse used to return a json
/// dictionary containing information on any errors
/// e.g. attempting to get a property, but an SKTResult that
/// is not .E_NOERROR was returned.
private protocol ErrorResponseProtocol: LocalizedError {
    var json: JSONDictionary { get }
}

/// Returns JSONDictionary containing information on errors
/// encountered during a get or set request
internal struct ErrorResponse: ErrorResponseProtocol {
    public private(set) var json: [String : Any]
    init(json: JSONDictionary) {
        self.json = json
    }
}




// MARK: - MaracaError

/// Errors that are thrown during the conversion of an
/// SKTProperty to a json dictionary
internal enum MaracaError: Error {
    
    /// The SKTAppInfo object contains invalid information.
    /// Likely cause is that `appInfo.verify(withBundleId:)` failed
    case invalidAppInfo(String)
    
    /// The SKTCaptureProperty has mismatching type and values
    /// e.g. The type == .array, but .arrayValue == nil
    case malformedCaptureProperty(String)
    
    /// The JSON RPC object is missing an important key-value pair
    /// e.g. The dictionary was expected to contain information
    /// to do a setProperty
    case malformedJson(String)
    
    /// The values within the JSON RPC object has the proper
    /// key, but its value is invalid
    /// e.g. The user wants to get the data source from a CaptureHelperDevice,
    /// but the data source Id they provide is not a case in the SKTCaptureDataSourceID enum.
    case invalidKeyValuePair(String)
    
    /// The property type is not supported at this time
    /// e.g. The .object and .enum type
    case propertyTypeNotSupported(String)
    
    /// The current installed version of Capture is not
    /// compatible with the version sent from the web application using CaptureJS
    case outdatedVersion(String)
}














// MARK: - ActiveClientManagerDelegate

@objc internal protocol ActiveClientManagerDelegate: class {
    
    /**
    Notifies the delegate that a CaptureHelper device has been connected
    Use this to refresh UI in iOS application
     
    Even if using Maraca and SKTCapture simultaneously, this function will
    only be called once, depending on which entity is set as the Capture delegate.
     
     - Parameters:
        - maraca: The ActiveClientManager object
        - device: Wrapper for the actual Bluetooth device
        - result: The result and/or possible error code for the notification
     */
    @objc optional func activeClient(_ manager: ActiveClientManager, didNotifyArrivalFor device: CaptureHelperDevice, result: SKTResult)
    
    /**
     Notifies the delegate that a CaptureHelper device has been disconnected
     Use this to refresh UI in iOS application
     
     Even if using Maraca and SKTCapture simultaneously, this function will
     only be called once, depending on which entity is set as the Capture delegate.
     
     - Parameters:
         - maraca: The ActiveClientManager object
         - device: Wrapper for the actual Bluetooth device
         - result: The result and/or possible error code for the notification
     */
    @objc optional func activeClient(_ manager: ActiveClientManager, didNotifyRemovalFor device: CaptureHelperDevice, result: SKTResult)
    
    /**
     Notifies the delegate that the battery level of aa CaptureHelperDevice has changed
     Use this to refresh UI in iOS application
     
     Even if using Maraca and SKTCapture simultaneously, this function will
     only be called once, depending on which entity is set as the Capture delegate.
     
     - Parameters:
         - maraca: The ActiveClientManager object
         - value: Current battery level for the device
         - device: Wrapper for the actual Bluetooth device
     */
    @objc optional func activeClient(_ manager: ActiveClientManager, batteryLevelDidChange value: Int, for device: CaptureHelperDevice)
}













/// unique identifier for a ClientDevice. The value will be the integer value of:
/// "The interval between the date value and 00:00:00 UTC on 1 January 1970."
public typealias ClientDeviceHandle = Int











// MARK: - String

extension String {
     
    /**
     Maintains "directory" of possibly encountered characters that need to be escaped.
     Otherwise, errors may occur
     
     In some cases, data returned from a CaptureHelperDevice will contain
     escaped characters (e.g. \n or \r)
     
     Strings containing these characters will result in a Javascript exception
     due to an unterminating string.
     
     Such characters are allowed in Swift, but often cause this exception when
     sent to a web page or server of some kind.
     
     This extension adds an extra backslash to the response json before it is sent.
     When this value is finally interpreted by the web page, the extra backslash is removed,
     revealing the original string-value.
     */
    enum escapeCharacters: String, CaseIterable {
        case nulTerminatoor     = "\0"
        case horizontalTab      = "\t"
        case newLine            = "\n"
        case carriageReturn     = "\r"
        case doubleQuote        = "\""
        case singleQuote        = "\'"
        case backslash          = "\\"
    }
    
    /// Returns String without error-causing characters that need to be escaped
    var escaped: String {
        let entities = [escapeCharacters.nulTerminatoor.rawValue:   "\\0",
                        escapeCharacters.horizontalTab.rawValue:    "\\t",
                        escapeCharacters.newLine.rawValue:          "\\n",
                        escapeCharacters.carriageReturn.rawValue:   "\\r",
                        escapeCharacters.doubleQuote.rawValue:      "\\\"",
                        escapeCharacters.singleQuote.rawValue:      "%27"
        ]
        
        return entities
            .reduce(self) { (string, entity) in
                string.replacingOccurrences(of: entity.key, with: entity.value)
            }
    }
    
    /// Determines whether error-causing characters that need to be escaped are contained in the String
    func containsEscapeCharacters() -> Bool {
        let characters = escapeCharacters.allCases.map ({ $0.rawValue }).joined()
        let characterSet = CharacterSet(charactersIn: characters)
        return self.rangeOfCharacter(from: characterSet) != nil
    }
}


// MARK: - SKTCaptureProperty extension

// These functions are used when doing a get or set property.
// The purpose is to either, deconstruct a SKTCaptureProperty
// into a JSON
// (in the case of getProperty, sending iOS/Swift-specific
//  values will result in a crash when using the JSONSerialization function)
//
// Or, to reconstruct the value of a SKTCaptureProperty from
// an incoming setProperty JSON

extension SKTCaptureProperty {
    
    /**
     Builds a JSONDictionary from the existing SKTCaptureProperty,
     which may be transferred to web application using CaptureJS
     
     - Parameters:
        - responseId: The unique identifier from the web application making the request
     */
    public func jsonFromGetProperty(with responseId: Int) throws -> JSONDictionary {
        
        // TODO
        // Some of these properties are iOS-specific
        // such as arrayValue which is Data,
        // dataSource which is a struct
        // Can Javascript read these types as-is?
        
        var propertyValue: Any!
        switch type {
        case .array:
            guard let data: Data = self.arrayValue else {
                // TODO
                // Unlikely to happen, but if the type == .array,
                // and the .arrayValue is nil, would this would be a bug?
                throw MaracaError.malformedCaptureProperty("The SKTCaptureProperty has type: \(type), but the corresponding value is nil")
            }
            propertyValue = [UInt8](data)
        case .byte:
            propertyValue = self.byteValue
        case .dataSource:
            guard let dataSource = self.dataSource, let dataSourceName = dataSource.name else {
                // Same error as (case .array)
                throw MaracaError.malformedCaptureProperty("The SKTCaptureProperty has type: \(type), but the corresponding value is nil")
            }
            propertyValue = [
                MaracaConstants.Keys.id.rawValue: dataSource.id.rawValue,
                MaracaConstants.Keys.status.rawValue: dataSource.status.rawValue,
                MaracaConstants.Keys.name.rawValue: dataSourceName,
                MaracaConstants.Keys.flags.rawValue: dataSource.flags.rawValue
            ]
            
        case .lastType:
            throw MaracaError.outdatedVersion("There is a version incompatibility error")
        case .notApplicable, .object, .enum:
            throw MaracaError.propertyTypeNotSupported("The SKTCaptureProperty has type: \(type) which is not supported at this time")
        case .string:
            if self.stringValue?.containsEscapeCharacters() == true {
                propertyValue = self.stringValue?.escaped
            } else {
                propertyValue = self.stringValue
            }
        case .ulong:
            propertyValue = self.uLongValue
        case .version:
            guard let version = self.version else {
                // Same error as (case .array)
                throw MaracaError.malformedCaptureProperty("The SKTCaptureProperty has type: \(type), but the corresponding value is nil")
            }
            
            propertyValue = [
                MaracaConstants.Keys.major.rawValue : version.major,
                MaracaConstants.Keys.middle.rawValue: version.middle,
                MaracaConstants.Keys.minor.rawValue : version.minor,
                MaracaConstants.Keys.build.rawValue : version.build,
                MaracaConstants.Keys.year.rawValue  : version.year,
                MaracaConstants.Keys.month.rawValue : version.month,
                MaracaConstants.Keys.day.rawValue   : version.day,
                MaracaConstants.Keys.hour.rawValue  : version.hour,
                MaracaConstants.Keys.minute.rawValue: version.minute
                ] as [String : Any]
            
        default: break
        }
        
        let jsonRpc: [String : Any] = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.id.rawValue : responseId,
            MaracaConstants.Keys.result.rawValue: [
                MaracaConstants.Keys.property.rawValue : [
                    MaracaConstants.Keys.id.rawValue : self.id.rawValue,
                    MaracaConstants.Keys.type.rawValue : self.type.rawValue,
                    MaracaConstants.Keys.value.rawValue : propertyValue
                ]
            ]
        ]
        
        return jsonRpc
    }
    
    
    
    
    
    
    
    
    
    
    /**
    Sets/Updates an existing SKTCaptureProperty value
    
    - Parameters:
       - valueFromJSON: The value contained within a JSONDictionary coming from web application using CaptureJS
    */
    public func setPropertyValue(using valueFromJson: Any) throws {
        switch type {
        case .array:
            guard let arrayOfBytes = valueFromJson as? [UInt8] else {
                throw MaracaError.malformedJson("The value from the JSON was expected to be of type [UInt8], instead it is: \(valueFromJson)")
            }
            let data = Data(arrayOfBytes)
            self.arrayValue = data
        case .byte:
            // TODO
            // byteValue is NOT optional
            // So you need to unwrap newProperty as an Int8
            // Force unwrapping here can lead to a crash if the user
            // specifies .byte for the type, but passes a value
            // that is not an Int8
            self.byteValue = valueFromJson as! Int8
        case .dataSource:
            
            guard let dictionary = valueFromJson as? JSONDictionary else {
                throw MaracaError.malformedJson("The value from the JSON was expected to be a dictionary of type JSONDictionary, instead it is: \(valueFromJson)")
            }
            
            guard
                let id = dictionary[MaracaConstants.Keys.id.rawValue] as? Int,
                let status = dictionary[MaracaConstants.Keys.status.rawValue] as? Int,
                let name = dictionary[MaracaConstants.Keys.name.rawValue] as? String,
                let flags = dictionary[MaracaConstants.Keys.flags.rawValue] as? Int
                else {
                    throw MaracaError.malformedJson("The value from the JSON was a dictionary of type JSONDictionary, but it did not contain all the necessary key-value pairs necessary for an SKTCaptureDataSource object")
            }
            
            let dataSource = SKTCaptureDataSource()
            
            guard let dataSourceId = SKTCaptureDataSourceID(rawValue: id) else {
                throw MaracaError.invalidKeyValuePair("The data source Id value provided: \(id) is not valid")
            }
            guard let dataSourceStatus = SKTCaptureDataSourceStatus(rawValue: status) else {
                throw MaracaError.invalidKeyValuePair("The data source status value provided: \(status) is not valid")
            }
            
            dataSource.id = dataSourceId
            dataSource.status = dataSourceStatus
            dataSource.name = name
            dataSource.flags = SKTCaptureDataSourceFlags(rawValue: flags)
            
            self.dataSource = dataSource
        case .lastType:
            throw MaracaError.outdatedVersion("There is a version incompatibility error")
        case .notApplicable, .object, .enum:
            throw MaracaError.propertyTypeNotSupported("The SKTCaptureProperty has type: \(type) which is not supported at this time")
        case .string:
            self.stringValue = valueFromJson as? String
        case .ulong:
            self.uLongValue = valueFromJson as! UInt
        case .version:
            
            guard let dictionary = valueFromJson as? JSONDictionary else {
                throw MaracaError.malformedJson("The value from the JSON was expected to be a dictionary of type JSONDictionary, instead it is: \(valueFromJson)")
            }
            
            guard
                let major = dictionary[MaracaConstants.Keys.major.rawValue] as? Int,
                let middle = dictionary[MaracaConstants.Keys.middle.rawValue] as? Int,
                let minor = dictionary[MaracaConstants.Keys.minor.rawValue] as? Int,
                let build = dictionary[MaracaConstants.Keys.build.rawValue] as? Int,
                let year = dictionary[MaracaConstants.Keys.year.rawValue] as? Int,
                let month = dictionary[MaracaConstants.Keys.month.rawValue] as? Int,
                let day = dictionary[MaracaConstants.Keys.day.rawValue] as? Int,
                let hour = dictionary[MaracaConstants.Keys.hour.rawValue] as? Int,
                let minute = dictionary[MaracaConstants.Keys.minor.rawValue] as? Int
                else {
                    throw MaracaError.malformedJson("The value from the JSON was a dictionary of type JSONDictionary, but it did not contain all the necessary key-value pairs necessary for an SKTCaptureVersion object")
            }
            
            let version = SKTCaptureVersion()
            version.major = UInt(major)
            version.middle = UInt(middle)
            version.minor = UInt(minor)
            version.build = UInt(build)
            version.year = Int32(year)
            version.month = Int32(month)
            version.day = Int32(day)
            version.hour = Int32(hour)
            version.minute = Int32(minute)
            
            self.version = version
        default: break
        }
    }
}









/// unique identifier for a Client. The value will be the integer value of
/// the interval between 00:00:00 UTC on 1 January 1970 and the current date
public typealias ClientHandle = Int

// MARK: - ClientConformanceProtocol

internal protocol ClientConformanceProtocol where Self: Client {
    
    /// Unique identifier for client
    var handle: ClientHandle! { get }
    
    /// Used to denote which client currently has active ownership of BLE devices
    var ownershipId: String { get }
    
    var appInfo: SKTAppInfo? { get }
    
    /// Used to identify/retrieve a client with a webview
    var webpageURLString: String? { get }
    
    /// Webview used to send and receive data to the current web application page using CaptureJS
    var webview: WKWebView? { get }
    
    /// Returns whether this Client has opened Capture
    var didOpenCapture: Bool { get }
    
    /// Keeps track of the capture helper devices that this client has opened.
    var openedDevices: [ClientDeviceHandle : ClientDevice] { get }
    
    
    init()
    
    
    
    
    
    
    // => add new Client Instance to clients list in Maraca
    // => AppInfo Verify ==> TRUE
    // => send device Arrivals if devices connected
    // => return a handle
    
    /**
     Establishes link between web application running CaptureJS and Maraca
     The return value is used to uniquely identify a web application page, allowing for operations to be performed
     
     Throws error if the appInfo cannot be verified using the AppID property
     
     Sends device arrival notifications if devices are connected and returns a unique identifier for the Client
     
     - Parameters:
        - appInfo: `SKTAppInfo` object constructed from incoming JSON
        - webview: The `WKWebView` that sent the JSON through script message handlers
     
     - Returns:
        - Returns a unique identifier for the Client if open was successful
     */
    @discardableResult func openWithAppInfo(appInfo: SKTAppInfo, webview: WKWebView) throws -> ClientHandle
        
    /**
     Called as a result of the web application requesting "ownership" of CaptureHelperDevice
     Opened devices can now perform get or set requests on SKTCaptureProperties and return
     the response to the web application
     
     - Parameters:
        - captureHelperDevice: Wrapper for the actual Bluetooth device
        - jsonRPCObject: Object conforming to the JSON-RPC format. Used to pass relevant data between web application and Maraca
     */
    func open(captureHelperDevice: CaptureHelperDevice, jsonRPCObject: JsonRPCObject)
    
    /**
     Closes a Client object with the maching unique identifier and returns a response to the web application
     
     - Parameters:
        - handle: The unique identifier of the Client
        - responseId: Response unique identifier interpreted by web application using CaptureJS
     */
    func close(handle: ClientHandle, responseId: Int)
    
    /// Closes all currently opened devices
    func closeAllDevices()
    
    /**
     Relinquishes or assumes ownership for a bluetooth device
     
     - Parameters:
        - handle: The unique identifier for the bluetooth device
        - isOwned: Determines whether to relinquish or assume ownership of the device
     */
    func changeOwnership(forClientDeviceWith handle: ClientDeviceHandle, isOwned: Bool)
    
    /**
     Returns whether a device with GUID has been opened by the Client
     
     - Parameters:
        - deviceGUID: The GUID of the device. Provided through `SKTCapture` framework
     
     - Returns:
        - Returns whether a device with GUID has been opened by the Client
     */
    func hasPreviouslyOpenedDevice(with deviceGuid: String) -> Bool
    
    /**
     Returns an internal Wrapper object for the device if one already exists and has been opened
     
     - Parameters:
        - device: The `SKTCapture` wrapper for the bluetooth device
     
     - Returns:
        - An internal wrapper for the bluetooth device
     */
    func getClientDevice(for device: CaptureHelperDevice) -> ClientDevice?
    
    /// Resumes responses to get and set requests
    func resume()
    
    /// Suspends responses to get and set requests
    func suspend()
    
    /**
     Sends responses containing information to a web application. Often responses contain requested data from get or set requests
     
     Additionally, the response may contain errors if any were encountered
     
     - Parameters:
        - jsonRpc: The "packet" containing the requested data or errors
     */
    func replyToWebpage(with jsonRpc: JSONDictionary)
    
    /**
    Notifies a web application of events such as Capture events (errors, device arrival, etc.)
    
    - Parameters:
       - jsonRpc: The "packet" containing the data or errors
    */
    func notifyWebpage(with jsonRpc: JSONDictionary)
}
