import Foundation

struct LoginContext {
    let callingCode: String
    let mobileNumber: String
    let fullNumber: String
    var verificationId: String?
}
