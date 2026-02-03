import Foundation
import MixinServices

extension Account {
    
    var isPhoneVerificationValid: Bool {
        if let verifiedAt = phoneVerifiedAt?.toUTCDate() {
            -verifiedAt.timeIntervalSinceNow <= 60 * .day
        } else {
            false
        }
    }
    
    func checkBuyTokenEligibility(
        onEligible: () -> Void,
        onVerificationNeeded: (PopupTipViewController) -> Void,
    ) {
        if isAnonymous {
            let tip = PopupTipViewController(tip: .addMobileNumber)
            onVerificationNeeded(tip)
        } else if isPhoneVerificationValid {
            onEligible()
        } else {
            let tip = PopupTipViewController(tip: .verifyMobileNumber)
            onVerificationNeeded(tip)
        }
    }
    
}
