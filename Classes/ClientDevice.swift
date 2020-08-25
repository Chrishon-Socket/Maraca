//
//  ClientDevice.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 11/18/19.
//

import Foundation
import SKTCapture

// Extensions do NOT support computed properties at this time (6/13/19)
// There's no "CLEAN" way to extend the CaptureHelperDevice
// with a property that lets us know which Clients have opened it.
// So, to get around that, this private struct
// maintains references to which CaptureHelperDevices have
// been opened by which Client objects

internal struct ClientDevice: ClientReceiverProtocol, Equatable, CustomStringConvertible {
    
    static func ==(lhs: ClientDevice, rhs: ClientDevice) -> Bool {
        return lhs.guid == rhs.guid || lhs.handle == rhs.handle
    }
    
    // MARK: - Variables
    
    var description: String {
        let printableDescription: String = "Device name: \(String(describing: captureHelperDevice.deviceInfo.name)). GUID: \(String(describing: captureHelperDevice.deviceInfo.guid)). Handle: \(handle)"
        return printableDescription
    }
    
    /// Wrapper for bluetooth device
    internal let captureHelperDevice: CaptureHelperDevice
    
    /// GUID of the bluetooth device
    internal var guid: String? {
        return captureHelperDevice.deviceInfo.guid
    }
    
    /// Unique identifer for the ClientDevice object
    internal let handle: ClientHandle
    
    
    
    // MARK: - Initializers
    
    init(captureHelperDevice: CaptureHelperDevice) {
        self.captureHelperDevice = captureHelperDevice
        self.handle = Utility.generateUniqueHandle()
    }
    
    
    
    
    
    
    
    // MARK: - Functions
    
    internal func getProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler) {
        captureHelperDevice.getProperty(property) { (result, resultProperty) in
            
            guard result == SKTResult.E_NOERROR else {
                let errorMessage = "There was an error with getting property from the CaptureHelperDevice. Error: \(result)"
                let errorResponseJsonRpc = Utility.constructErrorResponse(error: result,
                                                                         errorMessage: errorMessage,
                                                                         handle: self.handle,
                                                                         responseId: responseId)
                completion(.failure(ErrorResponse(json: errorResponseJsonRpc)))
                return
            }
            
            // Used a different name to differentiate between the three
            guard let unwrappedProperty = resultProperty else {
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
                let errorResponseJsonRpc = Utility.constructErrorResponse(error: SKTResult.E_INVALIDPARAMETER,
                                                                         errorMessage: error.localizedDescription,
                                                                         handle: self.handle,
                                                                         responseId: responseId)
                
                completion(.failure(ErrorResponse(json: errorResponseJsonRpc)))
            }
        }
    }
    
    internal func setProperty(property: SKTCaptureProperty, responseId: Int, completion: @escaping ClientReceiverCompletionHandler) {
        
        captureHelperDevice.setProperty(property) { (result, property) in
            
            guard result == .E_NOERROR else {
                
                let errorMessage = "There was an error with setting property of the CaptureHelperDevice. Error: \(result)"
                let errorResponseJsonRpc = Utility.constructErrorResponse(error: result,
                                                                         errorMessage: errorMessage,
                                                                         handle: self.handle,
                                                                         responseId: responseId)
                
                completion(.failure(ErrorResponse(json: errorResponseJsonRpc)))
                return
            }
            
            let jsonRpc: [String : Any] = [
                MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
                MaracaConstants.Keys.id.rawValue : responseId,
                MaracaConstants.Keys.result.rawValue: [
                    MaracaConstants.Keys.handle.rawValue : self.captureHelperDevice.deviceInfo.guid
                    // We might send the property back as well.
                ]
            ]
            
            completion(.success(jsonRpc))
        }
    }
}
