import Foundation
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

open class Reporter {
    
    public typealias UserInfo = [String: Any]
    
    public enum Event {
        case signUp
        case login
        case sendSticker
        case openApp
        
        public var name: String {
            switch self {
            case .signUp:
                return "sign_up"
            case .login:
                return "login"
            case .sendSticker:
                return "send_sticker"
            case .openApp:
                return "open_app"
            }
        }
    }
    
    public var basicUserInfo: UserInfo {
        ["last_update_or_install_date": AppGroupUserDefaults.User.lastUpdateOrInstallDate,
         "client_time": DateFormatter.filename.string(from: Date())]
    }
    
    public required init() {
    }

    open func configure() {
        guard let path = Bundle.main.path(forResource: "Mixin-Keys", ofType: "plist"), let keys = NSDictionary(contentsOfFile: path) as? [String: Any], let key = keys["AppCenter"] as? String else {
            return
        }
        
        MSAppCenter.start(key, withServices: [MSAnalytics.self, MSCrashes.self])

        if !isAppExtension {
            guard MSCrashes.hasCrashedInLastSession(), let crashReport = MSCrashes.lastSessionCrashReport() else {
                return
            }
            
            Logger.write(errorMsg: "[\(crashReport.signal ?? "")][\(crashReport.exceptionName ?? "")][\(crashReport.exceptionReason ?? "")]")
        }
    }

    open func registerUserInformation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        MSAppCenter.setUserId(account.user_id)

        var properties = MSCustomProperties()
        properties.setString(account.identity_number, forKey: "identity_number")
        properties.setString(account.full_name, forKey: "full_name")
        MSAppCenter.setCustomProperties(properties)
    }
    
    open func report(event: Event, userInfo: UserInfo? = nil) {
        if let userInfo = userInfo {
            var properties = [String: String]()
            userInfo.forEach { (key, value) in
                properties[key] = "\(value)"
            }
            MSAnalytics.trackEvent(event.name, withProperties: properties)
        } else {
            MSAnalytics.trackEvent(event.name)
        }
    }

    open func report(error: MixinAPIError) {

    }

    open func report(error: Error) {

    }
    
}
