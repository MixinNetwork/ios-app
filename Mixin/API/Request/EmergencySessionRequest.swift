import Foundation

struct EmergencySessionRequest: Codable {
    
    let purpose = "SESSION"
    let code: String?
    let sessionSecret: String?
    let platform = "iOS"
    let platformVersion = UIDevice.current.systemVersion
    let packageName = Bundle.main.bundleIdentifier ?? ""
    let appVersion = Bundle.main.shortVersion + "(" + Bundle.main.bundleVersion + ")"
    let registrationId: Int?
    
    enum CodingKeys: String, CodingKey {
        case purpose
        case code
        case sessionSecret = "session_secret"
        case platform
        case platformVersion = "platform_version"
        case packageName = "package_name"
        case appVersion = "app_version"
        case registrationId = "registration_id"
    }
    
}
