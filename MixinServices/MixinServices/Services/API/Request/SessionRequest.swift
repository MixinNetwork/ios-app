import Foundation

public struct SessionRequest {
    
    let platform = "iOS"
    let platformVersion = "" + UIDevice.current.systemVersion
    let packageName = Bundle.main.bundleIdentifier
    let appVersion = Bundle.main.shortVersionString
    let notificationToken: String?
    let voipToken: String?
    let deviceCheckToken: String?
    
}

extension SessionRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case platform
        case platformVersion = "platform_version"
        case packageName = "package_name"
        case appVersion = "app_version"
        case notificationToken = "notification_token"
        case voipToken = "voip_token"
        case deviceCheckToken = "device_check_token"
    }
    
}
