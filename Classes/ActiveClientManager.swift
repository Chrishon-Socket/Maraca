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
            self?.sendJSONForError(error: error)
        }
        captureLayer.deviceManagerArrivalHandler = { [weak self] (deviceManager, result) in
            self?.sendJSONForDevicePresence(device: deviceManager,
                                            result: result,
                                            deviceTypeID: SKTCaptureEventID.deviceManagerArrival)
        }
        captureLayer.deviceManagerRemovalHandler = { [weak self] (deviceManager, result) in
            self?.sendJSONForDevicePresence(device: deviceManager,
                                            result: result,
                                            deviceTypeID: SKTCaptureEventID.deviceManagerRemoval)
        }
        captureLayer.deviceArrivalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyArrivalFor: device, result: result)
            
            strongSelf.sendJSONForDevicePresence(device: device,
                                                 result: result,
                                                 deviceTypeID: SKTCaptureEventID.deviceArrival)
        }
        captureLayer.deviceRemovalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyRemovalFor: device, result: result)
            
            strongSelf.sendJSONForDevicePresence(device: device,
                                                 result: result,
                                                 deviceTypeID: SKTCaptureEventID.deviceRemoval)
        }
        captureLayer.powerStateHandler = { [weak self] (powerState, device) in
            self?.sendJSONForPowerState(powerState: powerState)
        }
        captureLayer.batteryLevelChangeHandler = { [weak self] (batteryLevel, device) in
            guard let strongSelf = self else { return }
            
            strongSelf.delegate?.activeClient?(strongSelf, batteryLevelDidChange: batteryLevel, for: device)
            
            strongSelf.sendJSONForBatteryLevelChange(batteryLevel: batteryLevel)
        }
        captureLayer.captureDataHandler = { [weak self] (decodedData, device, result) in
            self?.sendJSONForDecodedData(decodedData: decodedData,
                                         device: device,
                                         result: result)
        }
        captureLayer.buttonsStateHandler = { [weak self] (buttonsState, device) in
            self?.sendJSONForButtonsState(buttonsState: buttonsState, device: device)
        }
        return captureLayer
    }
    
    internal func resendDevicePresenceEvents() {
        guard let activeClient = Maraca.shared.activeClient else {
            return
        }
         
        let currentlyOpenedClientDevices: [ClientDevice] = Array(activeClient.openedDevices.values)
        let clientDeviceGuids: [String] = currentlyOpenedClientDevices.compactMap ({ $0.guid })
         
        let currentlyOpenedCaptureDevices: [CaptureHelperDevice] = Maraca.shared.capture.getDevices() + Maraca.shared.capture.getDeviceManagers()
        let captureHelperDeviceGuids: [String] = currentlyOpenedCaptureDevices.compactMap ({ $0.deviceInfo.guid })
        
        
        // Find all CaptureHelperDevices that have been removed while this Client
        // was suspended
        let expiredClientDevices: [ClientDevice] = currentlyOpenedClientDevices.filter { (clientDevice) -> Bool in
            guard let clientDeviceGuid = clientDevice.guid else {
                return false
            }
            return captureHelperDeviceGuids.contains(clientDeviceGuid) == false
        }
         
        // Find all new CaptureHelperDevices that have arrived while this Client
        // was suspended
        let uncaughtOpenedCaptureDevices: [CaptureHelperDevice] = currentlyOpenedCaptureDevices.filter { (captureHelperDevice) -> Bool in
            guard let captureHelperDeviceGuid = captureHelperDevice.deviceInfo.guid else {
                return false
            }
            return clientDeviceGuids.contains(captureHelperDeviceGuid) == false
        }
         
        // send JSON for these device arrival/removal events
        sendDeviceArrivalEvents(for: uncaughtOpenedCaptureDevices)
        sendDeviceRemovalEvents(for: expiredClientDevices)
        
        // Re-assume ownership of the existing opened devices
        activeClient.resume()
    }
    
    private func sendDeviceArrivalEvents(for uncaughtOpenedCaptureDevices: [CaptureHelperDevice]) {
        guard uncaughtOpenedCaptureDevices.isEmpty == false else {
            return
        }
        
        uncaughtOpenedCaptureDevices.forEach { (device) in
            
            var deviceTypeId: SKTCaptureEventID = .deviceArrival
            
            if device is CaptureHelperDeviceManager {
                deviceTypeId = .deviceManagerArrival
            }
            
            sendJSONForDevicePresence(device: device, result: SKTResult.E_NOERROR, deviceTypeID: deviceTypeId)
        }
    }
    
    private func sendDeviceRemovalEvents(for expiredClientDevices: [ClientDevice]) {
        guard expiredClientDevices.isEmpty == false else {
            return
        }
        expiredClientDevices.forEach { (clientDevice) in
            var deviceTypeId: SKTCaptureEventID = .deviceRemoval
            
            if clientDevice.captureHelperDevice is CaptureHelperDeviceManager {
                deviceTypeId = .deviceManagerRemoval
            }
            
            sendJSONForDevicePresence(device: clientDevice.captureHelperDevice,
                                      result: SKTResult.E_NOERROR,
                                      deviceTypeID: deviceTypeId)
        }
    }
}











// MARK: - Webpage communications

extension ActiveClientManager {
    
    internal func sendJSONForError(error: SKTResult) {
        guard let activeClient = Maraca.shared.activeClient else { return }
        let errorResponseJsonRpc = Utility.constructErrorResponse(error: error,
                                                                 errorMessage: "",
                                                                 handle: activeClient.handle,
                                                                 responseId: nil)
        
        activeClient.notifyWebpage(with: errorResponseJsonRpc)
    }
    
    internal func sendJSONForPowerState(powerState: SKTCapturePowerState) {
        guard
            let activeClient = Maraca.shared.activeClient,
            let clientHandle = activeClient.handle
            else {
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
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForBatteryLevelChange(batteryLevel: Int) {
        guard
            let activeClient = Maraca.shared.activeClient,
            let clientHandle = activeClient.handle
            else {
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
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForDevicePresence(device: CaptureHelperDevice, result: SKTResult, deviceTypeID: SKTCaptureEventID) {
        
        guard
            let activeClient = Maraca.shared.activeClient,
            let clientHandle = activeClient.handle
            else {
                return
        }
                      
        guard result == SKTResult.E_NOERROR else {
          
            let errorMessage = "There was an error with arrival or removal of the Socket Mobile device: \(String(describing: device.deviceInfo.name)). Error: \(result)"
            let errorResponseJsonRpc = Utility.constructErrorResponse(error: result,
                                                                     errorMessage: errorMessage,
                                                                     handle: activeClient.handle,
                                                                     responseId: nil)
          
            activeClient.notifyWebpage(with: errorResponseJsonRpc)
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
      
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForDecodedData(decodedData: SKTCaptureDecodedData?, device: CaptureHelperDevice, result: SKTResult) {
        
        guard
            let activeClient = Maraca.shared.activeClient,
            let clientHandle = activeClient.handle
            else {
                return
        }
       
        // E_CANCEL for case where Overlay view is cancelled
        guard result == SKTResult.E_NOERROR || result == SKTResult.E_CANCEL else {
           
            let errorResponseJsonRpc = Utility.constructErrorResponse(error: result,
                                                                    errorMessage: "There was an error receiving decoded data from the Socket Mobile device: \(String(describing: device.deviceInfo.name)). Error: \(result)",
                                                                    handle: activeClient.handle,
                                                                    responseId: nil)
           
            activeClient.notifyWebpage(with: errorResponseJsonRpc)
            return
        }
       
        guard
            let dataFromDecodedDataStruct = decodedData?.decodedData,
            let dataSourceName = decodedData?.dataSourceName,
            let dataSourceId = decodedData?.dataSourceID.rawValue
            else { return }
       
       
       
       
        // Confirm that the ClientDevice has been previously opened
        // by the active client
       
        guard activeClient.hasPreviouslyOpened(device: device) else {
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
       
        activeClient.notifyWebpage(with: jsonRpc)
    }
    
    internal func sendJSONForButtonsState(buttonsState: SKTCaptureButtonsState, device: CaptureHelperDevice) {
        guard
            let activeClient = Maraca.shared.activeClient,
            let clientHandle = activeClient.handle
            else {
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
        
        activeClient.notifyWebpage(with: jsonRpc)
    }
}
