import UIKit
import WebKit

class DAppWebView: WKWebView {

    class func instance() -> DAppWebView {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = .all
        config.preferences = WKPreferences()
        config.preferences.minimumFontSize = 12
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        return DAppWebView(frame: .zero, configuration: config)
    }

    class func clearCookies() {
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage], modifiedSince: Date(timeIntervalSince1970: 1)) {
        }
    }
}
