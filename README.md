# Maraca

[![CI Status](https://img.shields.io/travis/Chrishon/Maraca.svg?style=flat)](https://travis-ci.org/Chrishon/Maraca)
[![Version](https://img.shields.io/cocoapods/v/Maraca.svg?style=flat)](https://cocoapods.org/pods/Maraca)
[![License](https://img.shields.io/cocoapods/l/Maraca.svg?style=flat)](https://cocoapods.org/pods/Maraca)
[![Platform](https://img.shields.io/cocoapods/p/Maraca.svg?style=flat)](https://cocoapods.org/pods/Maraca)

Maraca establishes connections between your iOS application and a web application using our [CaptureJS SDK](#Link-capture-js-sdk-pending), allowing for such web applications to connect with and use our Socket Mobile scanners and NFC readers.

## Usage

```swift

private func setupMaraca() {
    
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

                   self?.setupUI()
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
