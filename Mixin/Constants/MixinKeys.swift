import Foundation

enum MixinKeys {
    
    static let keys: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Mixin-Keys", ofType: "plist") else {
            return [:]
        }
        return (NSDictionary(contentsOfFile: path) as? [String: Any]) ?? [:]
    }()
    
    enum Foursquare {
        
        static let clientId = dict?["ClientID"]
        static let clientSecret = dict?["ClientSecret"]
        
        private static let dict = keys["Foursquare"] as? [String: String]
        
    }
    
    static let reCaptcha = keys["ReCaptcha"] as? String
    static let hCaptcha = keys["hCaptcha"] as? String
    static let giphy = keys["Giphy"] as? String
    
}
