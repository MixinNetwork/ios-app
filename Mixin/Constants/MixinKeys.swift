import Foundation

enum MixinKeys {
    
    static let keys: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Mixin-Keys", ofType: "plist") else {
            return [:]
        }
        return (NSDictionary(contentsOfFile: path) as? [String: Any]) ?? [:]
    }()
    
    static let bugsnag = keys["Bugsnag"] as? String
    static let reCaptcha = keys["ReCaptcha"] as? String
    
}
