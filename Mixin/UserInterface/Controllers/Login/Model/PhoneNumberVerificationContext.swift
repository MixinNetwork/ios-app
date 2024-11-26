import Foundation
import MixinServices

struct PhoneNumberVerificationContext {
    
    let phoneNumber: String
    let displayPhoneNumber: String
    let deactivatedAt: String?
    
    var verificationID: String
    var hasEmergencyContact: Bool
    
}
