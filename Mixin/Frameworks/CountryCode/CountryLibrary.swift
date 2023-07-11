import Foundation
import CoreTelephony

class CountryLibrary {
    
    let countries: [Country]
    let deviceCountry: Country
    
    init() {
        let locale = Locale.current as NSLocale
        
        // Key is ISO Region Code
        let callingCodes: [String: Int] = {
            let url = Bundle.main.url(forResource: "CountryCode", withExtension: "plist")!
            let data = try! Data(contentsOf: url)
            let plist = try! PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            return plist as! [String: Int]
        }()
        
        let countries: [Country] = Locale.isoRegionCodes.compactMap { isoRegionCode in
            guard let callingCode = callingCodes[isoRegionCode] else {
                return nil
            }
            guard let localizedName = locale.displayName(forKey: .countryCode, value: isoRegionCode) else {
                return nil
            }
            return Country(callingCode: String(callingCode),
                           isoRegionCode: isoRegionCode.uppercased(),
                           localizedName: localizedName)
        }
        
        let deviceCountry: Country = {
            let carrierCountryCode: String? = {
                let result: String?
                let networkInfo = CTTelephonyNetworkInfo()
                if let id = networkInfo.dataServiceIdentifier, let code = networkInfo.serviceSubscriberCellularProviders?[id]?.isoCountryCode {
                    result = code.uppercased()
                } else if let code = networkInfo.serviceSubscriberCellularProviders?.values.compactMap(\.isoCountryCode).first {
                    result = code.uppercased()
                } else {
                    result = nil
                }
                if result == "--" {
                    // https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-16_4-release-notes
                    // CTCarrier, a deprecated API, returns static values for apps that are built with the iOS 16.4 SDK or later. (76283818)
                    return nil
                } else {
                    return result
                }
            }()
            let inferredCountryCode = (locale.object(forKey: .countryCode) as? String)?.uppercased()
            let deviceCountryCode = carrierCountryCode ?? inferredCountryCode
            
            if let code = deviceCountryCode, let country = countries.first(where: { $0.isoRegionCode == code }) {
                return country
            } else {
                return .us
            }
        }()
        
        self.countries = countries
        self.deviceCountry = deviceCountry
    }
    
}
