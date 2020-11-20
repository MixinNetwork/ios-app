import Foundation

struct SessionRequest: Encodable {
    
    let platform = "iOS"
    let platform_version = "" + UIDevice.current.systemVersion
    let package_name = Bundle.main.bundleIdentifier
    let app_version = Bundle.main.shortVersion
    let notification_token: String
    let voip_token: String
    let device_check_token: String
    
}

