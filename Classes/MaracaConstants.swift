//
//  MaracaConstants.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 11/18/19.
//

import Foundation

// Constants for commonly-used Strings

struct MaracaConstants {
    
    // These are key-values for dictionaries
    // e.g. The keys for a JSON-RPC object
    enum Keys: String {
        case jsonrpc = "jsonrpc"
        case id
        case method
        case params
        case handle
        
        case result
        case event
        case type
        case value
        case guid
        case name
        
        case property
        
        case error
        case code
        case message
        case data
        
        case symbology
        
        case appId
        case appKey
        case developerId
        
        
        case status
        case flags
        
        
        
        case major
        case middle
        case minor
        case build
        case year
        case month
        case day
        case hour
        case minute
    }
    
    struct Strings {
        // Used to set the device manager favorites to "all"
        // Allowing any RFID reader/writer to connect
        static let favoritesAll: String = "*"
    }
    
    struct DebugMode {
        
        private init() {}
        
        static let debugModeActivatedKey: String = "com.socketmobile.maraca.userdefaultskey.debug-mode.is-activated"
    }
    
}
