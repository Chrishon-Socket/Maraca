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
            self?.sendJSONForError(activeClient: activeClient, error: error)
        }
        captureLayer.deviceManagerArrivalHandler = { [weak self] (deviceManager, result) in
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForDevicePresence(activeClient: activeClient,
                                            device: deviceManager,
                                            result: result,
                                            deviceTypeID: SKTCaptureEventID.deviceManagerArrival)
        }
        captureLayer.deviceManagerRemovalHandler = { [weak self] (deviceManager, result) in
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForDevicePresence(activeClient: activeClient,
                                            device: deviceManager,
                                            result: result,
                                            deviceTypeID: SKTCaptureEventID.deviceManagerRemoval)
        }
        captureLayer.deviceArrivalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            guard let activeClient = Maraca.shared.activeClient else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyArrivalFor: device, result: result)
            
            strongSelf.sendJSONForDevicePresence(activeClient: activeClient,
                                                 device: device,
                                                 result: result,
                                                 deviceTypeID: SKTCaptureEventID.deviceArrival)
        }
        captureLayer.deviceRemovalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            guard let activeClient = Maraca.shared.activeClient else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyRemovalFor: device, result: result)
            
            strongSelf.sendJSONForDevicePresence(activeClient: activeClient,
                                                 device: device,
                                                 result: result,
                                                 deviceTypeID: SKTCaptureEventID.deviceRemoval)
        }
        captureLayer.powerStateHandler = { [weak self] (powerState, device) in
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForPowerState(activeClient: activeClient, powerState: powerState)
        }
        captureLayer.batteryLevelChangeHandler = { [weak self] (batteryLevel, device) in
            guard let strongSelf = self else { return }
            
            strongSelf.delegate?.activeClient?(strongSelf, batteryLevelDidChange: batteryLevel, for: device)
            
            guard let activeClient = Maraca.shared.activeClient else { return }
            strongSelf.sendJSONForBatteryLevelChange(activeClient: activeClient, batteryLevel: batteryLevel)
        }
        captureLayer.captureDataHandler = { [weak self] (decodedData, device, result) in
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForDecodedData(activeClient: activeClient,
                                         decodedData: decodedData,
                                         device: device,
                                         result: result)
        }
        captureLayer.buttonsStateHandler = { [weak self] (buttonsState, device) in
            guard let activeClient = Maraca.shared.activeClient else { return }
            self?.sendJSONForButtonsState(activeClient: activeClient,
                                          buttonsState: buttonsState,
                                          device: device)
        }
        return captureLayer
    }
}











// MARK: - Webpage communications

extension ActiveClientManager {
    
    internal func sendJSONForError(activeClient: Client, error: SKTResult) {
        // TODO
        // There is no information associated with the error
        let errorResponseJsonRpc = Utility.constructErrorResponse(error: error,
                                                                 errorMessage: "Some kind of error specific message",
                                                                 handle: activeClient.handle,
                                                                 responseId: nil)
        
        activeClient.notifyWebpage(with: errorResponseJsonRpc)
    }
    
    internal func sendJSONForPowerState(activeClient: Client, powerState: SKTCapturePowerState) {
        
        guard let clientHandle = activeClient.handle else { return }
        
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
    
    internal func sendJSONForBatteryLevelChange(activeClient: Client, batteryLevel: Int) {
        guard let clientHandle = activeClient.handle else { return }
        
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
    
    internal func sendJSONForDevicePresence(activeClient: Client, device: CaptureHelperDevice, result: SKTResult, deviceTypeID: SKTCaptureEventID) {
                      
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
            let deviceGuid = device.deviceInfo.guid,
            let clientHandle = activeClient.handle else {
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
    
    internal func sendJSONForDecodedData(activeClient: Client, decodedData: SKTCaptureDecodedData?, device: CaptureHelperDevice, result: SKTResult) {
        
        guard
            let clientHandle = activeClient.handle
            else { return }
       
        guard result == SKTResult.E_NOERROR else {
           
            let errorResponseJsonRpc = Utility.constructErrorResponse(error: result,
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
    
    internal func sendJSONForButtonsState(activeClient: Client, buttonsState: SKTCaptureButtonsState, device: CaptureHelperDevice) {
        guard let clientHandle = activeClient.handle else { return }
        
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
