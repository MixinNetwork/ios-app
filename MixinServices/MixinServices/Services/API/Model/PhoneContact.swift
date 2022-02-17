import Foundation

public class PhoneContact: NSObject, Codable {
    
    @objc public let fullName: String
    public let phoneNumber: String
    
    public init(fullName: String, phoneNumber: String) {
        self.fullName = fullName
        self.phoneNumber = phoneNumber
    }
    
}
