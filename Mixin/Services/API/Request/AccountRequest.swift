import Foundation
import UIKit

public struct AccountRequest: Codable {
    
    let code: String?
    let registrationId: Int?
    let platform: String = "iOS"
    let platformVersion: String = UIDevice.current.systemVersion
    let appVersion: String
    let packageName: String = Bundle.main.bundleIdentifier ?? ""
    let purpose: String
    var pin: String?
    let sessionSecret: String?
    
    enum CodingKeys: String, CodingKey {
        case code
        case registrationId = "registration_id"
        case platform
        case platformVersion = "platform_version"
        case appVersion = "app_version"
        case packageName = "package_name"
        case purpose
        case pin
        case sessionSecret = "session_secret"
    }
    
    static func createAccountRequest(verificationCode: String, registrationId: Int?, pin: String?, sessionSecret: String?) -> AccountRequest {
        let appVersion = Bundle.main.shortVersion + "(" + Bundle.main.bundleVersion + ")"
        let purpose = pin == nil ? VerificationPurpose.session.rawValue : VerificationPurpose.phone.rawValue
        return AccountRequest(code: verificationCode, registrationId: registrationId, appVersion: appVersion, purpose: purpose, pin: pin, sessionSecret: sessionSecret)
    }
    
}

public enum VerificationPurpose: String {
    case session = "SESSION"
    case phone = "PHONE"
}
