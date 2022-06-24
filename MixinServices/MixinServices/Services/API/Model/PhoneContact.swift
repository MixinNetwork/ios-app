import Foundation

public class PhoneContact: NSObject, Codable {
    
    @objc public let fullName: String
    public let phoneNumber: String
    
    public init(fullName: String, phoneNumber: String) {
        self.fullName = fullName
        self.phoneNumber = phoneNumber
    }
    
    public func matches(lowercasedKeyword keyword: String) -> Bool {
        fullName.lowercased().contains(keyword) || (phoneNumber.contains(keyword) ?? false)
    }
    
}
