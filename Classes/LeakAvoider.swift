//
//  LeakAvoider.swift
//  Maraca
//
//  Created by Chrishon Wyllie on 11/20/19.
//

import WebKit.WKScriptMessageHandler

// The `WKUserContentController` and `WKScriptMessageHandler`
// causes a memory leak because it retains `self` by default
// A work-around was to create a "middle" object that specifies
// a `weak` delegate
// https://stackoverflow.com/questions/26383031/wkwebview-causes-my-view-controller-to-leak

public class LeakAvoider: NSObject, WKScriptMessageHandler {
    
    public weak var delegate: WKScriptMessageHandler?
    
    public init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.delegate?.userContentController(userContentController, didReceive: message)
    }
}
