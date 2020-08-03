//
//  ViewController.swift
//  Maraca
//
//  Created by Chrishon on 11/19/2019.
//  Copyright (c) 2019 Chrishon. All rights reserved.
//

import UIKit
import WebKit
import Maraca

class ViewController: UIViewController {
    
    // MARK: - Variables
    
    // These message handlers may come from you own web application
    enum YourOwnMessageHandlers: String, CaseIterable {
        case someMessageHandler = "someMessageHandler"
        // Add as many as you need...
    }
    
    
    
    // MARK: - UI Elements
    
    private let tabsSelectionView = TabsSelectionView()
        
    private let tabsStackView = TabsStackView()
    
    private var defaultToolbarItems: [UIBarButtonItem] {
        return [
            UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(ViewController.addNewTab)),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        ]
    }
    
    
    
    
    
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        setupNavigation()
        setupMaraca()
        
        // This can be called either in the Maraca Setup completion
        // handler or here
//        setupUIElements()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}


// MARK: - Setup functions

extension ViewController {
    
    private func setupMaraca() {
        
        let appKey =        "MC4CFQDmrCRRlaSC33YMekHZlboDEd9rJwIVAJvB5rzcoMavKHJGBFEGVGJn5kN4"
        let appId =         "ios:com.socketmobile.Maraca-Example"
        let developerId =   "bb57d8e1-f911-47ba-b510-693be162686a"
        let bundle = Bundle.main
        
        Maraca.shared.injectCustomJavascript(mainBundle: bundle, javascriptFileNames: ["getInputForDecodedData"])
            .observeJavascriptMessageHandlers(YourOwnMessageHandlers.allCases.map { $0.rawValue })
            .setDelegate(to: self)
            .begin(withAppKey: appKey,
                   appId: appId,
                   developerId: developerId,
                   completion: { (result) in
                    print("result: \(result.rawValue)")
                       self.setupUIElements()
            })
    }
    
    private func setupNavigation() {
        
        self.edgesForExtendedLayout = UIRectEdge()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        toolbarItems = defaultToolbarItems
        
        navigationController?.setToolbarHidden(false, animated: false)
        
        if #available(iOS 13.0, *) {
            self.navigationController?.toolbar.barTintColor = UIColor.secondarySystemBackground
        } else {
            // Fallback on earlier versions
            // Use default
        }
    }
    
    private func setupUIElements() {
        
        tabsSelectionView.didSelectItem { (indexPath, _) in
            self.tabsStackView.pushTabToTop(index: indexPath.item)
        }
        view.addSubview(tabsSelectionView)
        view.addSubview(tabsStackView)
        
        tabsSelectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        if #available(iOS 11.0, *) {
            tabsSelectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            tabsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else {
            // Fallback on earlier versions
            tabsSelectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            tabsStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        }
        tabsSelectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tabsSelectionView.heightAnchor.constraint(equalToConstant: 120.0).isActive = true
        
        tabsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tabsStackView.topAnchor.constraint(equalTo: tabsSelectionView.bottomAnchor).isActive = true
        tabsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        addNewTab()
        
    }
    
    @objc private func addNewTab() {
        
        let webview: TabWebview = {
            let w = TabWebview(frame: .zero, configuration: Maraca.shared.webViewConfiguration)
            w.translatesAutoresizingMaskIntoConstraints = false
            w.contentMode = UIView.ContentMode.redraw
            w.navigationDelegate = self
            return w
        }()
        
        let url = getURLForTestPage()
        
        let tab = Tab(title: "some title", url: url, webview: webview)
        tabsSelectionView.add(tab: tab)
        tabsStackView.add(tab: tab)
    }
    
    private func getURLForTestPage() -> URL {
        let urlString = "https://capturesdkjavascript.z4.web.core.windows.net/maraca/test.html"
        
        guard let url = URL(string: urlString) else {
            fatalError("This URL no longer exists")
        }
        
        return url
    }
}


























// MARK: - WKNavigationDelegate

extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler( WKNavigationActionPolicy.allow )
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        
        // Check if a Client exists for the url that this WKWebView
        // is loading
        // Perhaps the user performed these actions in this order:
        //
        // 1) navigate to their web application (with CaptureJS enabled)
        // 2) opened a new client
        // 3) navigate to http://www.google.com to research one of our products
        // 4) click a link to http://www.socketmobile.com/products to view up one of our products
        // 5) manually navigate to their web application (instead of just pressing the back button)
        //
        // In this case, we want to retrieve the client that was opened in step 2
        // and reactivate this client
        if let client = Maraca.shared.getClients(for: webView)?.first {
            
            Maraca.shared.activateClient(client)
        } else {
            
            // Otherwise, this WKWebView is loading
            // a completely different web app that
            // may not be using CaptureJS
            // Return SKTCapture delegation to Rumba.
            // But since this is called before the WKScriptMessageHandler,
            // the "completely different web app" will open
            // Capture with its own AppInfo if it is using CaptureJS
            if let _ = Maraca.shared.activeClient {
                Maraca.shared.resignActiveClient()
            }
            
            
            // Tell Capture within this app to "become" the delegate
            self.becomeCaptureResponder()
        }
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateTab(for: webView as! TabWebview)
    }
    
    private func updateTab(for webView: TabWebview) {
        
        guard let title = webView.title, let url = webView.url else {
            return
        }
        let updatedTab = Tab(title: title, url: url, webview: webView)
        
        let index = tabsSelectionView.indexOf(tab: updatedTab) ?? 0
        
        tabsSelectionView.updateTab(at: index, with: updatedTab)
        tabsStackView.updateTab(at: index, tab: updatedTab)
    }
}














// MARK: - MaracaDelegate

extension ViewController: MaracaDelegate {
    
    func maraca(_ maraca: Maraca, webviewDidOpenCaptureWith client: Client) {
        print("clients count: \(maraca.clientsList.count)")
        for (key, value) in maraca.clientsList {
            print("key: \(key), value: \(value)")
        }
    }
    
    func maraca(_ maraca: Maraca, webviewDidCloseCaptureWith client: Client) {
        becomeCaptureResponder()
    }
    
    func maraca(_ maraca: Maraca, didReceive scriptMessage: WKScriptMessage) {
        // Otherwise, handle your own message handlers

//        guard let messageBody = message.body as? String, let webview = message.webView else {
//            return
//        }
    }
    
    
    
    
    // This is called from the WebviewController when
    // a new web page is loaded that does not use CaptureJS
    private func becomeCaptureResponder() {
        // Extend the CaptureHelperDelegate if you'd like to return
        // control of Capture to "this" view controller.
        // Then uncomment the next line
//        Maraca.shared.resignCaptureDelegate(to: self)
    }
        
}
