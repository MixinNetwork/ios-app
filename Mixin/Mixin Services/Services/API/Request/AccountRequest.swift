import Foundation
import UIKit

public struct AccountRequest: Codable {
    
    public let code: String?
    public let registrationId: Int?
    public let platform: String = "iOS"
    public let platformVersion: String = UIDevice.current.systemVersion
    public let appVersion: String
    public let packageName: String = Bundle.main.bundleIdentifier ?? ""
    public let purpose: String
    public var pin: String?
    public let sessionSecret: String?
    
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
    
    public init(code: String?, registrationId: Int?, pin: String?, sessionSecret: String?) {
        self.code = code
        self.registrationId = registrationId
        self.appVersion = Bundle.main.shortVersion + "(" + Bundle.main.bundleVersion + ")"
        self.purpose = pin == nil ? VerificationPurpose.session.rawValue : VerificationPurpose.phone.rawValue
        self.pin = pin
        self.sessionSecret = sessionSecret
    }
    
}

public enum VerificationPurpose: String {
    case session = "SESSION"
    case phone = "PHONE"
}
