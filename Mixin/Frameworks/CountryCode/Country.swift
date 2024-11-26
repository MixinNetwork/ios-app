import Foundation
import MixinServices

final class Country: NSObject {
    
    static let us = {
        let locale = Locale.current as NSLocale
        let localizedName = locale.displayName(forKey: .countryCode, value: "us") ?? "United States"
        return Country(callingCode: "1", isoRegionCode: "US", localizedName: localizedName)
    }()
    
    static let anonymous = Country(
        callingCode: anonymousCallingCode,
        isoRegionCode: anonymousCallingCode,
        localizedName: "Mixin"
    )
    
    let callingCode: String
    let isoRegionCode: String
    @objc let localizedName: String
    
    init(callingCode: String, isoRegionCode: String, localizedName: String) {
        self.callingCode = callingCode
        self.isoRegionCode = isoRegionCode
        self.localizedName = localizedName
    }
    
    static func == (lhs: Country, rhs: Country) -> Bool {
        lhs.isoRegionCode == rhs.isoRegionCode
    }
    
}
