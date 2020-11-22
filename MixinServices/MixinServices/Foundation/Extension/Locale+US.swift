import Foundation

public extension Locale {
    
    public static let us = Locale(identifier: "US")
    public static let preferred: Locale = {
        if let id = Locale.preferredLanguages.first {
            return Locale(identifier: id)
        } else {
            return .current
        }
    }()
    
}
