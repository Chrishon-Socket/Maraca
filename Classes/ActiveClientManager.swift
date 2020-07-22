//
//  ActiveClientManager.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 7/22/20.
//

import SKTCapture

class ActiveClientManager: NSObject {
    
    private(set) var activeClient: Client?
    
    private var captureLayer: SKTCaptureLayer!
    
    private weak var delegate: ActiveClientManagerDelegate?
    
    internal func update(activeClient: Client?) {
        self.activeClient = activeClient
    }
    
    init(delegate: ActiveClientManagerDelegate?) {
        super.init()
        self.delegate = delegate
        captureLayer = setupCaptureLayer()
    }
    
    var captureDelegate: CaptureHelperAllDelegate {
        return captureLayer
    }
    
    private func setupCaptureLayer() -> SKTCaptureLayer {
        
        let captureLayer = SKTCaptureLayer()
        
        captureLayer.errorEventHandler = { [weak self] (error) in
            guard let activeClient = self?.activeClient else { return }
            captureLayer.sendJSONForError(activeClient: activeClient, error: error)
        }
        captureLayer.deviceManagerArrivalHandler = { [weak self] (deviceManager, result) in
            guard let activeClient = self?.activeClient else { return }
            captureLayer.sendJSONForDevicePresence(activeClient: activeClient,
                                                   device: deviceManager,
                                                   result: result,
                                                   deviceTypeID: SKTCaptureEventID.deviceManagerArrival)
        }
        captureLayer.deviceManagerRemovalHandler = { [weak self] (deviceManager, result) in
            guard let activeClient = self?.activeClient else { return }
            captureLayer.sendJSONForDevicePresence(activeClient: activeClient,
                                                   device: deviceManager,
                                                   result: result,
                                                   deviceTypeID: SKTCaptureEventID.deviceManagerRemoval)
        }
        captureLayer.deviceArrivalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            guard let activeClient = strongSelf.activeClient else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyArrivalFor: device, result: result)
            
            captureLayer.sendJSONForDevicePresence(activeClient: activeClient,
                                                   device: device,
                                                   result: result,
                                                   deviceTypeID: SKTCaptureEventID.deviceArrival)
        }
        captureLayer.deviceRemovalHandler = { [weak self] (device, result) in
            guard let strongSelf = self else { return }
            guard let activeClient = strongSelf.activeClient else { return }
            strongSelf.delegate?.activeClient?(strongSelf, didNotifyRemovalFor: device, result: result)
            
            captureLayer.sendJSONForDevicePresence(activeClient: activeClient,
                                                   device: device,
                                                   result: result,
                                                   deviceTypeID: SKTCaptureEventID.deviceRemoval)
        }
        captureLayer.powerStateHandler = { [weak self] (powerState, device) in
            guard let activeClient = self?.activeClient else { return }
            captureLayer.sendJSONForPowerState(activeClient: activeClient, powerState: powerState)
        }
        captureLayer.batteryLevelChangeHandler = { [weak self] (batteryLevel, device) in
            guard let strongSelf = self else { return }
            
            strongSelf.delegate?.activeClient?(strongSelf, batteryLevelDidChange: batteryLevel, for: device)
            
            guard let activeClient = strongSelf.activeClient else { return }
            captureLayer.sendJSONForBatteryLevelChange(activeClient: activeClient, batteryLevel: batteryLevel)
        }
        captureLayer.captureDataHandler = { [weak self] (decodedData, device, result) in
            guard let activeClient = self?.activeClient else { return }
            captureLayer.sendJSONForDecodedData(activeClient: activeClient,
                                                decodedData: decodedData,
                                                device: device,
                                                result: result)
        }
        captureLayer.buttonsStateHandler = { [weak self] (buttonsState, device) in
            guard let activeClient = self?.activeClient else { return }
            captureLayer.sendJSONForButtonsState(activeClient: activeClient, buttonsState: buttonsState, device: device)
        }
        return captureLayer
    }
}












@objc internal protocol ActiveClientManagerDelegate: class {
    @objc optional func activeClient(_ manager: ActiveClientManager, didNotifyArrivalFor device: CaptureHelperDevice, result: SKTResult)
    
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
    @objc optional func activeClient(_ manager: ActiveClientManager, didNotifyRemovalFor device: CaptureHelperDevice, result: SKTResult)
    
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
    @objc optional func activeClient(_ manager: ActiveClientManager, batteryLevelDidChange value: Int, for device: CaptureHelperDevice)
}
