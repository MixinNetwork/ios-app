import Foundation

struct LoginContext {
    
    let callingCode: String
    let mobileNumber: String
    let fullNumber: String
    var verificationId = ""
    var hasEmergencyContact = false
    
    init(callingCode: String, mobileNumber: String, fullNumber: String) {
        self.callingCode = callingCode
        self.mobileNumber = mobileNumber
        self.fullNumber = fullNumber
    }
    
}
