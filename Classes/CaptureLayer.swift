//
//  CaptureLayer.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 7/22/20.
//

import SKTCapture

internal typealias SKTCaptureErrorResultHandler = (SKTResult) -> ()
internal typealias SKTCaptureDeviceManagerArrivalHandler = (CaptureHelperDeviceManager, SKTResult) -> ()
internal typealias SKTCaptureDeviceManagerRemovalHandler = (CaptureHelperDeviceManager, SKTResult) -> ()
internal typealias SKTCaptureDeviceArrivalHandler = (CaptureHelperDevice, SKTResult) -> ()
internal typealias SKTCaptureDeviceRemovalHandler = (CaptureHelperDevice, SKTResult) -> ()
internal typealias SKTCaptureDataHandler = (SKTCaptureDecodedData?, CaptureHelperDevice, SKTResult) -> ()
internal typealias SKTCapturePowerStateHandler = (SKTCapturePowerState, CaptureHelperDevice) -> ()
internal typealias SKTCaptureBatteryLevelChangeHandler = (Int, CaptureHelperDevice) -> ()
internal typealias SKTCaptureButtonsStateHandler = (SKTCaptureButtonsState, CaptureHelperDevice) -> ()


internal class SKTCaptureLayer:
    NSObject,
    CaptureHelperAllDelegate
{
    
    internal var errorEventHandler: SKTCaptureErrorResultHandler?
    internal var deviceManagerArrivalHandler: SKTCaptureDeviceManagerArrivalHandler?
    internal var deviceManagerRemovalHandler: SKTCaptureDeviceManagerRemovalHandler?
    internal var deviceArrivalHandler: SKTCaptureDeviceArrivalHandler?
    internal var deviceRemovalHandler: SKTCaptureDeviceRemovalHandler?
    internal var captureDataHandler: SKTCaptureDataHandler?
    internal var powerStateHandler: SKTCapturePowerStateHandler?
    internal var batteryLevelChangeHandler: SKTCaptureBatteryLevelChangeHandler?
    internal var buttonsStateHandler: SKTCaptureButtonsStateHandler?
    
    
    override init() {
        super.init()
    }
    
    
    
    
    
    
    func didReceiveError(_ error: SKTResult) {
        
        errorEventHandler?(error)
    }
    
    func didNotifyArrivalForDeviceManager(_ device: CaptureHelperDeviceManager, withResult result: SKTResult) {
        
        deviceManagerArrivalHandler?(device, result)

    }
    
    func didNotifyRemovalForDeviceManager(_ device: CaptureHelperDeviceManager, withResult result: SKTResult) {
    
        deviceManagerRemovalHandler?(device, result)
        
    }
    
    func didNotifyArrivalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
    
        deviceArrivalHandler?(device, result)
        
    }
    
    func didNotifyRemovalForDevice(_ device: CaptureHelperDevice, withResult result: SKTResult) {
    
        deviceRemovalHandler?(device, result)
        
    }
    
    func didChangePowerState(_ powerState: SKTCapturePowerState, forDevice device: CaptureHelperDevice) {
        
        powerStateHandler?(powerState, device)
    }
    
    func didChangeBatteryLevel(_ batteryLevel: Int, forDevice device: CaptureHelperDevice) {
        
        batteryLevelChangeHandler?(batteryLevel, device)
        
    }
    
    func didReceiveDecodedData(_ decodedData: SKTCaptureDecodedData?, fromDevice device: CaptureHelperDevice, withResult result: SKTResult) {
       
        captureDataHandler?(decodedData, device, result)
        
    }
    
    func didChangeButtonsState(_ buttonsState: SKTCaptureButtonsState, forDevice device: CaptureHelperDevice) {
        
        buttonsStateHandler?(buttonsState, device)
    }
    
}








extension SKTCaptureLayer {
    
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
