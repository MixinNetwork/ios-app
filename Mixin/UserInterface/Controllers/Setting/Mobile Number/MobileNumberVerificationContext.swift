import Foundation
import MixinServices

struct MobileNumberVerificationContext {
    
    enum Intent {
        
        case periodicVerification
        case addMobileNumber
        case changeMobileNumber
        
        var verificationPurpose: VerificationPurpose {
            switch self {
            case .periodicVerification:
                    .none
            case .addMobileNumber, .changeMobileNumber:
                    .phone
            }
        }
        
    }
    
    let intent: Intent
    let pin: String
    
    var base64Salt = ""
    var verificationID = ""
    var newNumber = ""
    var newNumberRepresentation = ""
    
}
