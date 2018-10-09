import Foundation
import GiphyCoreSDK

extension GPHMedia {
    
    var mixinImageURL: URL? {
        guard let str = images?.fixedWidth?.gifUrl else {
            return nil
        }
        return URL(string: str)
    }
    
}

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
