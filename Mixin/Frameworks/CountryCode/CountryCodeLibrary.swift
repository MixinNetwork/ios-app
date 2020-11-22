import Foundation
import CoreTelephony

struct CountryCodeLibrary {
    
    static let shared = CountryCodeLibrary()
    
    let callingCodes: [String: NSNumber] // Key is ISO Region Code
    let countries: [Country]
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
        
        let networkInfo = CTTelephonyNetworkInfo()
        let dataServiceIdentifier: String? = {
            if #available(iOS 13.0, *) {
                return networkInfo.dataServiceIdentifier
            } else {
                return nil
            }
        }()
        let carrierCountryCode: String? = {
            if let id = dataServiceIdentifier, let code = networkInfo.serviceSubscriberCellularProviders?[id]?.isoCountryCode {
                return code.uppercased()
            } else if let code = networkInfo.serviceSubscriberCellularProviders?.values.compactMap(\.isoCountryCode).first {
                return code.uppercased()
            } else {
                return nil
            }
        }()
        let inferredCountryCode = (locale.object(forKey: .countryCode) as? String)?.uppercased()
        let deviceCountryCode = carrierCountryCode ?? inferredCountryCode
        
        if let country = countries.first(where: { $0.isoRegionCode == deviceCountryCode }) {
            deviceCountry = country
        } else {
            deviceCountry = Country(callingCode: "1", isoRegionCode: "US", localizedName: "United States", usLocalizedName: "United States")
        }
    }
    
}
