import Foundation
import MixinServices

struct PhoneNumberVerificationContext {
    
    let phoneNumber: String
    let displayPhoneNumber: String
    let deactivation: Deactivation?
    
    var verificationID: String
    var hasEmergencyContact: Bool
    
}
