//
//  TabsStackView.swift
//  Maraca_Example
//
//  Created by Chrishon Wyllie on 7/29/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import WebKit.WKWebView
import Maraca

class TabWebview: WKWebView {
    let uniqueIdentifier = UUID().uuidString
}

extension RangeReplaceableCollection where Indices: Equatable {
    mutating func rearrange(from: Index, to: Index) {
        precondition(from != to && indices.contains(from) && indices.contains(to), "invalid indices")
        insert(remove(at: from), at: to)
    }
}

class TabsStackView: UIView {
    
    private var webviews: [TabWebview] = []
    private weak var currentWebView: TabWebview? {
        didSet {
            guard let clientToResume = Maraca.shared.getClients(for: currentWebView!)?.first
            else {
                return
            }
        
            Maraca.shared.activateClient(clientToResume)
        }
    }
    
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func indexOf(tabWebview: TabWebview) -> Int? {
        return webviews.firstIndex(of: tabWebview)
    }
    
    func add(tab: Tab) {
        webviews.append(tab.webview)
        currentWebView = tab.webview
        let urlRequest = URLRequest(url: tab.url)
        tab.webview.load(urlRequest)
        setupConstraints(for: tab.webview)
    }
    
    func pushTabToTop(index: Int) {
        let requestedWebview = webviews[index]
        currentWebView = requestedWebview
//        webviews.rearrange(from: index, to: 0)
        bringSubview(toFront: requestedWebview)
    }
    
    func updateTab(at index: Int, tab: Tab) {
//        let existingWebview = webviews[index]
//        existingWebview.removeFromSuperview()
//        webviews[index] = tab.webview
    }
    
    func removeTab(at index: Int) {
        let webview = webviews[index]
        webview.removeFromSuperview()
        webviews.remove(at: index)
        currentWebView = webviews.last
    }
    
    private func setupConstraints(for webview: TabWebview) {
        addSubview(webview)
        webview.translatesAutoresizingMaskIntoConstraints = false
        webview.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        webview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        webview.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        webview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        layoutIfNeeded()
    }
    
}
