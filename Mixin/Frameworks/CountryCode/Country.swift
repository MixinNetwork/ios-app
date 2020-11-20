import Foundation

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
