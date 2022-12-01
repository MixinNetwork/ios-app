import Foundation

enum PhoneNumberError: Error {
    
    case generalError
    case invalidCountryCode
    case notANumber
    case unknownType
    case tooShort
    case ambiguousNumber(phoneNumbers: [PhoneNumber])
    
}
