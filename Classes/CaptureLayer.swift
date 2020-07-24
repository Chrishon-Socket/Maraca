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

/// Manages events from `SKTCapture` and notifies receiver
internal class SKTCaptureLayer: NSObject, CaptureHelperAllDelegate {
    
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
