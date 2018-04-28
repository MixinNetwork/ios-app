import Foundation
import CoreTelephony

class Country: NSObject {
    let callingCode: String
    let isoRegionCode: String
    @objc let localizedName: String
    let usLocalizedName: String
    
    init(callingCode: String, isoRegionCode: String, localizedName: String, usLocalizedName: String) {
        self.callingCode = callingCode
        self.isoRegionCode = isoRegionCode
        self.localizedName = localizedName
        self.usLocalizedName = usLocalizedName
    }
}

struct CountryCodeLibrary {
    
    static let shared = CountryCodeLibrary()
    
    let callingCodes: [String: NSNumber] // Key is ISO Region Code
    let countries: [Country]
    let isChina: Bool
    let deviceCountry: Country
    
    init() {
        let plist = Bundle.main.path(forResource: "CountryCode", ofType: "plist")!
        callingCodes = NSDictionary(contentsOfFile: plist)! as! [String : NSNumber]
        var countries = [Country]()
        let locale = Locale.current as NSLocale
        let usLocale = NSLocale(localeIdentifier: "en_US")
        for isoRegionCode in Locale.isoRegionCodes {
            guard let callingCode = callingCodes[isoRegionCode] else { continue }
            guard let localizedName = locale.displayName(forKey: NSLocale.Key.countryCode, value: isoRegionCode) else { continue }
            guard let usLocalizedName = usLocale.displayName(forKey: NSLocale.Key.countryCode, value: isoRegionCode) else { continue }
            let country = Country(callingCode: String(callingCode.intValue), isoRegionCode: isoRegionCode.uppercased(), localizedName: localizedName, usLocalizedName: usLocalizedName)
            countries.append(country)
        }
        countries.sort(by: { (pre: Country, next: Country) -> Bool in
            return pre.localizedName.localizedCompare(next.localizedName) == .orderedAscending
        })
        self.countries = countries
        
        let deviceISOCountryCode: String
        if let carrier = CTTelephonyNetworkInfo().subscriberCellularProvider, let isoCountryCode = carrier.isoCountryCode?.lowercased(), let mobileCountryCode = carrier.mobileCountryCode {
            isChina = isoCountryCode == "cn" || mobileCountryCode == "460"
            deviceISOCountryCode = isoCountryCode.uppercased()
        } else if let countryCode = locale.object(forKey: NSLocale.Key.countryCode) as? String {
            isChina = countryCode.lowercased() == "cn"
            deviceISOCountryCode = countryCode.uppercased()
        } else {
            isChina = false
            deviceISOCountryCode = "US"
        }
        
        if let country = countries.first(where: { $0.isoRegionCode == deviceISOCountryCode }) {
            deviceCountry = country
        } else {
            deviceCountry = Country(callingCode: "1", isoRegionCode: "US", localizedName: "United States", usLocalizedName: "United States")
        }
    }
    
}
