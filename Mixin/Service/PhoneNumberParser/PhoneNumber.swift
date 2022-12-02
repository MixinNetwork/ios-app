import Foundation

enum PhoneNumberType: String, Codable {
    
    case fixedLine
    case mobile
    case fixedOrMobile
    case pager
    case personalNumber
    case premiumRate
    case sharedCost
    case tollFree
    case voicemail
    case voip
    case uan
    case unknown
    case notParsed
    
}

struct PhoneNumber {
    
    let numberString: String
    let countryCode: UInt64
    let leadingZero: Bool
    let nationalNumber: UInt64
    let numberExtension: String?
    let type: PhoneNumberType
    let regionID: String?
    
}

extension PhoneNumber {
    
    func adjustedNationalNumber() -> String {
        if leadingZero == true {
            return "0" + String(nationalNumber)
        } else {
            return String(nationalNumber)
        }
    }
    
}
