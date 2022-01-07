import Foundation
import WebKit

extension WKWebsiteDataStore {
    
    func removeAuthenticationRelatedData() {
        let types: Set<String> = [
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeServiceWorkerRegistrations,
        ]
        removeData(ofTypes: types, modifiedSince: .distantPast, completionHandler: {})
    }
    
}
