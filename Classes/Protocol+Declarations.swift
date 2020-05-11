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


/// Public optional delegate used by Maraca class.
@objc public protocol MaracaDelegate: class {
    @objc optional func maraca(_ maraca: Maraca, webviewDidOpenCaptureWith client: Client)
    @objc optional func maraca(_ maraca: Maraca, webviewDidCloseCaptureWith client: Client)
    func maraca(_ maraca: Maraca, didReceive scriptMessage: WKScriptMessage)
}




internal extension Bundle {
    // Name of the app - title under the icon.
    var displayName: String? {
            return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}


/// New Swift 5.0 property to be used in completion handlers that
/// providers either a .success or .failure.
/// The first argument is the success result, the second is the failure result
public typealias ResultResponse = Result<[String: Any], ErrorResponse>

/// Typealias for common completion handler
public typealias ClientReceiverCompletionHandler = (ResultResponse) -> ()

/// Anonymous closure that takes the ResultResponse as a parameter
/// and returns a json (whether for failure or success)
public let resultDictionary: (ResultResponse) -> [String: Any] = { (result) in
    switch result {
    case .failure(let errorResponse):
        return errorResponse.json
    case .success(let successResponseJsonRpc):
        return successResponseJsonRpc
    }
}







/// A protocol adopted by both the Client and ClientDevice objects
/// It provides a set of functions/properties that both objects must implement
public protocol ClientReceiverProtocol {
    func getProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler)
    func setProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler)
}






/// The ErrorResponse struct is used to return a json
/// dictionary containing information on any errors
/// e.g. attempting to get a property, but an SKTResult that
/// is not .E_NOERROR was returned.
private protocol ErrorResponseProtocol: LocalizedError {
    var json: [String: Any] { get }
}

public struct ErrorResponse: ErrorResponseProtocol {
    public private(set) var json: [String : Any]
    init(json: [String: Any]) {
        self.json = json
    }
}





/// Errors that are thrown during the conversion of an
/// SKTProperty to a json dictionary

public enum MaracaError: Error {
    
    case invalidAppInfo(String)
    
    // The SKTCaptureProperty has mismatching type and values
    // e.g. The type == .array, but .arrayValue == nil
    case malformedCaptureProperty(String)
    
    // The JSON RPC object is missing an important key-value pair
    // e.g. The dictionary was expected to contain information
    // to do a setProperty
    case malformedJson(String)
    
    // The values within the JSON RPC object has the proper
    // key, but its value is invalid
    // e.g. The user wants to get the data source from a CaptureHelperDevice,
    // but the data source Id they provide is not a case in the SKTCaptureDataSourceID enum.
    case invalidKeyValuePair(String)
    
    // The property type is not supported at this time
    // e.g. The .object and .enum type
    case propertyTypeNotSupported(String)
    
    // The current installed version of Capture is not
    // compatible with the version sent from the web application using CaptureJS
    case outdatedVersion(String)
}








/// unique identifier for a Client. The value will be the integer value of:
/// "The interval between the date value and 00:00:00 UTC on 1 January 1970."
public typealias ClientHandle = Int





/// unique identifier for a ClientDevice. The value will be the integer value of:
/// "The interval between the date value and 00:00:00 UTC on 1 January 1970."
public typealias ClientDeviceHandle = Int













extension String {
    // In some cases, data returned from a CaptureHelperDevice will contain
    // escaped characters (e.g. \n or \r)
    // Strings containing these characters will result in a Javascript exception
    // due to an unterminating string.
    // Such characters are allowed in Swift, but often cause this exception when
    // sent to a web page or server of some kind.
    // This extension adds an extra backslash to the response json before it is sent.
    // When this value is finally interpreted by the web page, the extra backslash is removed,
    // revealing the original string-value.
    
    enum escapeCharacters: String, CaseIterable {
        case zero               = "\0"
        case horizontalTab      = "\t"
        case newLine            = "\n"
        case carriageReturn     = "\r"
        case doubleQuote        = "\""
        case singleQuote        = "\'"
        case backslash          = "\\"
    }
    
    var escaped: String {
        let entities = [escapeCharacters.zero.rawValue:             "\\0",
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
    
    public func jsonFromGetProperty(with responseId: Int) throws -> [String: Any] {
        
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
        case .none, .notApplicable, .object, .enum:
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
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? "2.0",
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
            
            guard let dictionary = valueFromJson as? [String: Any] else {
                throw MaracaError.malformedJson("The value from the JSON was expected to be a dictionary of type [String: Any], instead it is: \(valueFromJson)")
            }
            
            guard
                let id = dictionary[MaracaConstants.Keys.id.rawValue] as? Int,
                let status = dictionary[MaracaConstants.Keys.status.rawValue] as? Int,
                let name = dictionary[MaracaConstants.Keys.name.rawValue] as? String,
                let flags = dictionary[MaracaConstants.Keys.flags.rawValue] as? Int
                else {
                    throw MaracaError.malformedJson("The value from the JSON was a dictionary of type [String: Any], but it did not contain all the necessary key-value pairs necessary for an SKTCaptureDataSource object")
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
        case .none, .notApplicable, .object, .enum:
            throw MaracaError.propertyTypeNotSupported("The SKTCaptureProperty has type: \(type) which is not supported at this time")
        case .string:
            self.stringValue = valueFromJson as? String
        case .ulong:
            self.uLongValue = valueFromJson as! UInt
        case .version:
            
            guard let dictionary = valueFromJson as? [String: Any] else {
                throw MaracaError.malformedJson("The value from the JSON was expected to be a dictionary of type [String: Any], instead it is: \(valueFromJson)")
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
                    throw MaracaError.malformedJson("The value from the JSON was a dictionary of type [String: Any], but it did not contain all the necessary key-value pairs necessary for an SKTCaptureVersion object")
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
