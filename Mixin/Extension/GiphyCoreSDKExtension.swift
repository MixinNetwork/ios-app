import Foundation
import GiphyCoreSDK

extension GPHLanguageType {
    
    static let current: GPHLanguageType = {
        guard let language = Locale.current.languageCode else {
            return .english
        }
        let rawValue: String
        if language == "zh", let regionCode = Locale.current.regionCode {
            rawValue = language + "-" + regionCode
        } else {
            rawValue = language
        }
        return GPHLanguageType(rawValue: rawValue) ?? .english
    }()
    
}
