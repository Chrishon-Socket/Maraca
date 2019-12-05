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
    
    
    private var webview: WKWebView!
    
    

    
    
    
    
    
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

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
                   completion: { (completed) in
                       self.setupUIElements()
            })
    }
    
    private func setupUIElements() {
    
        webview = {
            let w = WKWebView(frame: .zero, configuration: Maraca.shared.webViewConfiguration)
            w.translatesAutoresizingMaskIntoConstraints = false
            w.contentMode = UIView.ContentMode.redraw
            w.navigationDelegate = self
            return w
        }()
        
        view.addSubview(webview)
        
        webview.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        if #available(iOS 11.0, *) {
            webview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            webview.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else {
            // Fallback on earlier versions
            webview.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            webview.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        }
        webview.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        loadTestPage()
        
    }
    
    private func loadTestPage() {
        let urlString = "https://capturesdkjavascript.z4.web.core.windows.net/maraca/test.html"
        
        guard let url = URL(string: urlString) else {
            fatalError("This URL no longer exists")
        }
        
        let urlRequest = URLRequest(url: url)
        webview.load(urlRequest)
        
    }
}


























// MARK: - WKNavigationDelegate

extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let webviewURL = webView.url?.absoluteString {
            print("webview url from navigation: \(String(describing: webviewURL))")
        }
        switch navigationAction.navigationType {
        case .backForward:
            print("back forward")
        case .formResubmitted:
            print("form resubmitted")
        case .formSubmitted:
            print("form submitted")
        case .linkActivated:
            print("link activated")
        case .other:
            print("other")
        case .reload:
            print("reload")
        }
        
        
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
        if let webpageURLString = webView.url?.absoluteString, let client = Maraca.shared.getClient(for: webpageURLString) {
            
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
