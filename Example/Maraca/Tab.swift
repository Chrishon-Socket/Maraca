//
//  Tab.swift
//  Maraca_Example
//
//  Created by Chrishon Wyllie on 7/29/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import WebKit.WKWebView

struct Tab: Equatable {
    static func ==(lhs: Tab, rhs: Tab) -> Bool {
        return lhs.webview.uniqueIdentifier == rhs.webview.uniqueIdentifier
    }
    let uniqueIdentifier = UUID().uuidString
    let title: String
    let url: URL
    weak var webview: TabWebview!
}
