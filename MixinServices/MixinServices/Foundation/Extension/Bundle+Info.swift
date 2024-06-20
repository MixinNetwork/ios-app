import Foundation

public extension Bundle {
    
    var shortVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var bundleVersion: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var bundleName: String {
        return infoDictionary?["CFBundleName"] as? String ?? ""
    }
    
}
