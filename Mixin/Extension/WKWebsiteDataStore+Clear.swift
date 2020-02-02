import Foundation
import WebKit

extension WKWebsiteDataStore {
    
    func removeAllCookiesAndLocalStorage() {
        removeData(ofTypes: [WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage], modifiedSince: .distantPast, completionHandler: {})
    }
    
}
