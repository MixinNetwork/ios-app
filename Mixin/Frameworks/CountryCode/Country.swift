import Foundation

class Country: NSObject {
    
    static let anonymous = Country(callingCode: "XIN", isoRegionCode: "XIN", localizedName: "Mixin")
    
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
