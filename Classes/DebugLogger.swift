//
//  DebugLogger.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 7/22/20.
//

import Foundation

public class DebugLogger {
    
    public static let shared = DebugLogger()
    private var debugMessages: [String] = []
    private var withNsLog = true
    
    private init(withNsLog: Bool = true) {
        self.withNsLog = withNsLog
        clear()
    }
    
    public func toggleDebug(isActivated: Bool? = nil) {
        let key = MaracaConstants.DebugMode.debugModeActivatedKey
        let currentBoolValue = UserDefaults.standard.bool(forKey: key)
        let newBoolValue = isActivated ?? !currentBoolValue
        UserDefaults.standard.set(newBoolValue, forKey: key)
    }
    
    public func addDebugMessage(_ message: String) {
        if UserDefaults.standard.bool(forKey: MaracaConstants.DebugMode.debugModeActivatedKey) == false {
            return
        }
        if self.withNsLog {
            #if DEBUG
            NSLog(message)
            #endif
        }
        debugMessages.append(message)
    }
    
    public func getAllMessages() -> [String] {
        return debugMessages
    }
    
    public func clear() {
        debugMessages.removeAll()
    }
}
