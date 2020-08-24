//
//  ActiveClientManager.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 7/22/20.
//

import SKTCapture

/// Manages relations between the currently active Client object and the web application it represents
class ActiveClientManager: NSObject {
    
    // MARK: - Variables
    
    private var captureLayer: SKTCaptureLayer!
    
    private weak var delegate: ActiveClientManagerDelegate?
    
    var captureDelegate: CaptureHelperAllDelegate {
        return captureLayer
    }
    
    
    
    
    // MARK: - Initializers
    
    init(delegate: ActiveClientManagerDelegate?) {
        super.init()
        self.delegate = delegate
        captureLayer = setupCaptureLayer()
    }
    
    
    
    
    // MARK: - Functions
    
    private func setupCaptureLayer() -> SKTCaptureLayer {
        
        let captureLayer = SKTCaptureLayer()
        
        captureLayer.errorEventHandler = { [weak self] (error) in
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForError(client: activeClient, error: error)
        }
        captureLayer.deviceManagerArrivalHandler = { [weak self] (deviceManager, result) in
            Array(Maraca.shared.clientsList.values).forEach { (client) in
                self?.sendJSONForDevicePresence(client: client,
                                                device: deviceManager,
                                                result: result,
                                                deviceTypeID: SKTCaptureEventID.deviceManagerArrival)
            }
        }
        captureLayer.deviceManagerRemovalHandler = { [weak self] (deviceManager, result) in
            Array(Maraca.shared.clientsList.values).forEach { (client) in
                self?.sendJSONForDevicePresence(client: client,
                                                device: deviceManager,
                                                result: result,
                                                deviceTypeID: SKTCaptureEventID.deviceManagerRemoval)
            }
        }
        captureLayer.deviceArrivalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyArrivalFor: device, result: result)
            
            Array(Maraca.shared.clientsList.values).forEach { (client) in
                strongSelf.sendJSONForDevicePresence(client: client,
                                                     device: device,
                                                     result: result,
                                                     deviceTypeID: SKTCaptureEventID.deviceArrival)
            }
        }
        captureLayer.deviceRemovalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyRemovalFor: device, result: result)
            
            Array(Maraca.shared.clientsList.values).forEach { (client) in
                strongSelf.sendJSONForDevicePresence(client: client,
                                                     device: device,
                                                     result: result,
                                                     deviceTypeID: SKTCaptureEventID.deviceRemoval)
            }
        }
        captureLayer.powerStateHandler = { [weak self] (powerState, device) in
            Array(Maraca.shared.clientsList.values).forEach { (client) in
                self?.sendJSONForPowerState(client: client, powerState: powerState)
            }
        }
        captureLayer.batteryLevelChangeHandler = { [weak self] (batteryLevel, device) in
            guard let strongSelf = self else { return }
            
            strongSelf.delegate?.activeClient?(strongSelf, batteryLevelDidChange: batteryLevel, for: device)
            
            Array(Maraca.shared.clientsList.values).forEach { (client) in
                strongSelf.sendJSONForBatteryLevelChange(client: client, batteryLevel: batteryLevel)
            }
            
        }
        captureLayer.captureDataHandler = { [weak self] (decodedData, device, result) in
            
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForDecodedData(client: activeClient,
                                         decodedData: decodedData,
                                         device: device,
                                         result: result)
        }
        captureLayer.buttonsStateHandler = { [weak self] (buttonsState, device) in
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForButtonsState(client: activeClient, buttonsState: buttonsState, device: device)
        }
        return captureLayer
    }
    
    /// Resends device arrival JSON to newly activated client.
    /// Purpose:
    /// A newly activated client will not be aware of Capture Devices that
    /// arrived before its activation.
    /// This function notifies new Clients with the current list of devices
    internal func resendDeviceArrivalEvents(for client: Client) {
         
        let currentlyOpenedCaptureDevices: [CaptureHelperDevice] = Maraca.shared.capture.getDevices() + Maraca.shared.capture.getDeviceManagers()
         
        // send JSON for these device arrival events
        currentlyOpenedCaptureDevices.forEach { (device) in
            
            var deviceTypeId: SKTCaptureEventID = .deviceArrival
            
            if device is CaptureHelperDeviceManager {
                deviceTypeId = .deviceManagerArrival
            }
            
            sendJSONForDevicePresence(client: client,
                                      device: device,
                                      result: SKTResult.E_NOERROR,
                                      deviceTypeID: deviceTypeId)
        }
        
        // Re-assume ownership of the existing opened devices
        client.resume()
    }
}











// MARK: - Webpage communications

extension ActiveClientManager {
    
    internal func sendJSONForError(client: Client, error: SKTResult) {
        let errorResponseJsonRpc = Utility.constructErrorResponse(error: error,
                                                                 errorMessage: "",
                                                                 handle: client.handle,
                                                                 responseId: nil)
        
        client.notifyWebpage(with: errorResponseJsonRpc)
    }
    
    internal func sendJSONForPowerState(client: Client, powerState: SKTCapturePowerState) {
        guard let clientHandle = client.handle else {
            return
        }
        
        let jsonRpc: JSONDictionary = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : SKTCaptureEventID.power.rawValue,
                    MaracaConstants.Keys.type.rawValue : SKTCaptureEventDataType.byte.rawValue,
                    MaracaConstants.Keys.value.rawValue : powerState.rawValue
                ]
            ]
        ]
        
        client.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForBatteryLevelChange(client: Client, batteryLevel: Int) {
        guard let clientHandle = client.handle else {
            return
        }
        
        let jsonRpc: JSONDictionary = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : SKTCaptureEventID.batteryLevel.rawValue,
                    MaracaConstants.Keys.type.rawValue : SKTCaptureEventDataType.byte.rawValue,
                    MaracaConstants.Keys.value.rawValue : batteryLevel
                ]
            ]
        ]
        
        client.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForDevicePresence(client: Client, device: CaptureHelperDevice, result: SKTResult, deviceTypeID: SKTCaptureEventID) {
        
        guard let clientHandle = client.handle else {
            return
        }
                      
        guard result == SKTResult.E_NOERROR else {
          
            let errorMessage = "There was an error with arrival or removal of the Socket Mobile device: \(String(describing: device.deviceInfo.name)). Error: \(result)"
            let errorResponseJsonRpc = Utility.constructErrorResponse(error: result,
                                                                     errorMessage: errorMessage,
                                                                     handle: client.handle,
                                                                     responseId: nil)
          
            client.notifyWebpage(with: errorResponseJsonRpc)
            return
        }
      
        guard
            let deviceName = device.deviceInfo.name?.escaped,
            let deviceGuid = device.deviceInfo.guid
            else {
                return
        }
      
        // Send the deviceArrival to the web app along with its guid
        // The web app may ignore this, but when it is ready to open
        // the device, it will send the guid back to Maraca
        // in order to open this device.
        
        let jsonRpc: JSONDictionary = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : deviceTypeID.rawValue,
                    MaracaConstants.Keys.type.rawValue : SKTCaptureEventDataType.deviceInfo.rawValue,
                    MaracaConstants.Keys.value.rawValue : [
                        MaracaConstants.Keys.guid.rawValue : deviceGuid,
                        MaracaConstants.Keys.name.rawValue : deviceName,
                        MaracaConstants.Keys.type.rawValue : device.deviceInfo.deviceType.rawValue
                    ]
                ]
            ]
        ]
      
        client.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForDecodedData(client: Client, decodedData: SKTCaptureDecodedData?, device: CaptureHelperDevice, result: SKTResult) {
        
        guard let clientHandle = client.handle else {
            return
        }
       
        // E_CANCEL for case where Overlay view is cancelled
        guard result == SKTResult.E_NOERROR || result == SKTResult.E_CANCEL else {
           
            let errorResponseJsonRpc = Utility.constructErrorResponse(error: result,
                                                                    errorMessage: "There was an error receiving decoded data from the Socket Mobile device: \(String(describing: device.deviceInfo.name)). Error: \(result)",
                                                                    handle: client.handle,
                                                                    responseId: nil)
           
            client.notifyWebpage(with: errorResponseJsonRpc)
            return
        }
       
        guard
            let dataFromDecodedDataStruct = decodedData?.decodedData,
            let dataSourceName = decodedData?.dataSourceName,
            let dataSourceId = decodedData?.dataSourceID.rawValue
            else { return }
       
       
       
       
        // Confirm that the ClientDevice has been previously opened
        // by the active client
       
        guard client.hasPreviouslyOpened(device: device) else {
            return
        }
       
        let dataAsIntegerArray: [UInt8] = [UInt8](dataFromDecodedDataStruct)
       
        let jsonRpc: JSONDictionary = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : SKTCaptureEventID.decodedData.rawValue,
                    MaracaConstants.Keys.type.rawValue : SKTCaptureEventDataType.decodedData.rawValue,
                    MaracaConstants.Keys.value.rawValue : [
                        MaracaConstants.Keys.data.rawValue : dataAsIntegerArray,
                        MaracaConstants.Keys.id.rawValue : dataSourceId,
                        MaracaConstants.Keys.name.rawValue : dataSourceName
                    ]
                ]
            ]
        ]
       
        client.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForButtonsState(client: Client, buttonsState: SKTCaptureButtonsState, device: CaptureHelperDevice) {
        guard let clientHandle = client.handle else {
            return
        }
        
        let jsonRpc: JSONDictionary = [
            MaracaConstants.Keys.jsonrpc.rawValue : Maraca.jsonRpcVersion ?? Maraca.defaultJsonRpcVersion,
            MaracaConstants.Keys.result.rawValue : [
                MaracaConstants.Keys.handle.rawValue : clientHandle,
                MaracaConstants.Keys.event.rawValue : [
                    MaracaConstants.Keys.id.rawValue : SKTCaptureEventID.buttons.rawValue,
                    MaracaConstants.Keys.type.rawValue : SKTCaptureEventDataType.byte.rawValue,
                    MaracaConstants.Keys.value.rawValue : buttonsState.rawValue,
                    
                ]
            ]
        ]
        
        client.notifyWebpage(with: jsonRpc)
    }
}
