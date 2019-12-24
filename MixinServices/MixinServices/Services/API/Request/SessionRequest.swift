import Foundation

internal struct SessionRequest: Codable {
    
    let platform = "iOS"
    let platform_version = "" + UIDevice.current.systemVersion
    let app_version = Bundle.main.shortVersion + "(" + Bundle.main.bundleVersion + ")"
    let notification_token: String
    let voip_token: String
    let device_check_token: String
    
}

