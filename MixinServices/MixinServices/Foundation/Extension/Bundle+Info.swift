import Foundation

public extension Bundle {
    
    var shortVersion: SemanticVersion? {
        SemanticVersion(string: shortVersionString)
    }
    
    var fullVersion: String {
        Bundle.main.shortVersionString + "(\(Bundle.main.bundleVersion))"
    }
    
    var shortVersionString: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "(null)"
    }

    var bundleVersion: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var bundleName: String {
        return infoDictionary?["CFBundleName"] as? String ?? ""
    }
    
}
