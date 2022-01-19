import Foundation

struct LoginContext {
    
    let callingCode: String
    let mobileNumber: String
    let fullNumber: String
    var verificationId = ""
    var hasEmergencyContact = false
    var isDeleting: Bool = false
    var deactivatedAt: String?
    
    init(callingCode: String, mobileNumber: String, fullNumber: String) {
        self.callingCode = callingCode
        self.mobileNumber = mobileNumber
        self.fullNumber = fullNumber
    }
    
}
