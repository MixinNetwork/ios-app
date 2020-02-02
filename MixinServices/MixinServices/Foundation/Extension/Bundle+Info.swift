import Foundation

public extension Bundle {
    
    static let mixinServicesResource: Bundle = {
        let frameworkBundle = Bundle(for: Localized.self)
        let url = frameworkBundle.url(forResource: "MixinServicesResource",
                                      withExtension: "bundle")!
        return Bundle(url: url)!
    }()
    
    var shortVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var bundleVersion: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var bundleName: String {
        return infoDictionary?["CFBundleName"] as? String ?? ""
    }
    
    var displayName: String {
        return localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? ""
    }
    
}
