import Foundation
import MixinServices

struct PhoneNumberVerificationContext {
    
    enum Intent {
        case signIn
        case signUp
    }
    
    let intent: Intent
    let phoneNumber: String
    let displayPhoneNumber: String
    let deactivation: Deactivation?
    
    var verificationID: String
    var hasEmergencyContact: Bool
    
}
