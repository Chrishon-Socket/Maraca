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
    
    private(set) var activeClient: Client?
    
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
    
    internal func update(activeClient: Client?) {
        self.activeClient = activeClient
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
