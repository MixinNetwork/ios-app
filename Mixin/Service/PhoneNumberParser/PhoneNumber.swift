import Foundation

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
