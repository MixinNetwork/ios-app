import Foundation
import MixinServices

struct MobileNumberLoginContext {
    
    let phoneNumber: String
    let displayPhoneNumber: String
    let deactivation: Deactivation?
    
    var verificationID: String
    var hasEmergencyContact: Bool
    
}
