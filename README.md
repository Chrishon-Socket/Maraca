# Maraca

[![CI Status](https://img.shields.io/travis/Chrishon/Maraca.svg?style=flat)](https://travis-ci.org/Chrishon/Maraca)
[![Version](https://img.shields.io/cocoapods/v/Maraca.svg?style=flat)](https://cocoapods.org/pods/Maraca)
[![License](https://img.shields.io/cocoapods/l/Maraca.svg?style=flat)](https://cocoapods.org/pods/Maraca)
[![Platform](https://img.shields.io/cocoapods/p/Maraca.svg?style=flat)](https://cocoapods.org/pods/Maraca)

Maraca establishes connections between your iOS application using our [iOS Capture SDK](https://github.com/SocketMobile/cocoapods-capture) and a web application using our [CaptureJS SDK](https://docs.socketmobile.com/capturejs/en/latest/gettingStarted.html). This enables the web application to connect with our scanners and NFC readers with the same flexibilty that our iOS SDK provides.

## Usage

Under the hood, Maraca is an umbrella for our iOS Capture SDK. So naturally, you need to provide credentials to get started. 

The most important step is to call `observeJavascriptMessageHandlers(_:)`
You may provide your own Javascript Message Handler names if you're familiar with [WKUserContentController](https://developer.apple.com/documentation/webkit/wkusercontentcontroller). Otherwise, this can be nil.
This function enables messages containing data to be transferred from your web application using CaptureJS to your iOS application.

Inside the completion handler of `beging(withAppKey:appId:developerId:completion:)`, create your `WKWebView` using the public `Maraca.shared.webViewConfiguration` configuration

```swift

override func viewDidLoad() {
    super.viewDidLoad()

    setupMaraca()
}

private func setupMaraca() {
    
    // If you are unfamiliar with the Socket Mobile Capture SDK
    let appKey =        <Your App Key>
    let appId =         <App ID>
    let developerId =   <Your Developer ID>
    let bundle = Bundle.main
    
    Maraca.shared.injectCustomJavascript(mainBundle: bundle, javascriptFileNames: ["getInputForDecodedData"])
        .observeJavascriptMessageHandlers(YourOwnMessageHandlers.allCases.map { $0.rawValue })
        .setDelegate(to: self)
        .begin(withAppKey: appKey,
               appId: appId,
               developerId: developerId,
               completion: { [weak self] (result) in

                    if result == .E_NOERROR {
                        self?.setupUI()
                    } else {
                        // Encountered some error, inspect result
                    }
        })
}

private func setupUI() {

    let webview = {
        let w = WKWebView(frame: .zero, configuration: Maraca.shared.webViewConfiguration)
        w.navigationDelegate = self
        return w
    }()
    
    view.addSubview(webview)
    
    // Set up constraints, etc..
    
    let myWebApplicationURLString = .....
    
    guard let url = URL(string: myWebApplicationURLString) else {
        return
    }
    
    loadMyWebApplication(with: url)
    
}

```

## Documentation

Full documentation can be found [here](https://docs.socketmobile.com/rumba/en/latest/maraca.html)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

Maraca is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Maraca'
```

## Author

Chrishon, chrishon@socketmobile.com

## License

Maraca is available under the MIT license. See the LICENSE file for more info.
