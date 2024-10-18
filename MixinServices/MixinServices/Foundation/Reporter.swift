import Foundation
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import AppsFlyerLib

open class Reporter {
    
    public typealias UserInfo = [String: Any]
    
    public enum Event {
        case signUp
        case login
        case sendSticker
        case openApp
        case cancelAudioRecording
        
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
            case .cancelAudioRecording:
                return "cancel_audio_record"
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
        guard let path = Bundle.main.path(forResource: "Mixin-Keys", ofType: "plist"), let keys = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return
        }
        
        if let appCenterKey = keys["AppCenter"] as? String {
            AppCenter.start(withAppSecret: appCenterKey, services: [Analytics.self, Crashes.self])
        }
        
        if let appsFlyerKeys = keys["AppCenter"] as? [String: String], let appID = appsFlyerKeys["AppID"], let devKey = appsFlyerKeys["DevKey"] {
            AppsFlyerLib.shared().appsFlyerDevKey = devKey
            AppsFlyerLib.shared().appleAppID = appID
        }
        
        if !isAppExtension, Crashes.hasCrashedInLastSession, let report = Crashes.lastSessionCrashReport {
            Logger.general.info(category: "LastCrash", message: "Signal: \(report.signal), exception: \(report.exceptionName ?? "(null)"), reason: \(report.exceptionReason ?? "(null)")")
        }
    }

    open func registerUserInformation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        AppCenter.userId = account.userID
        
        AppsFlyerLib.shared().customerUserID = account.userID
    }
    
    open func report(event: Event, userInfo: UserInfo? = nil) {
        if let userInfo = userInfo {
            var properties = [String: String]()
            userInfo.forEach { (key, value) in
                properties[key] = "\(value)"
            }
            Analytics.trackEvent(event.name, withProperties: properties)
        } else {
            Analytics.trackEvent(event.name)
        }
    }

    open func report(error: MixinAPIError) {

    }

    open func report(error: Error) {

    }
    
}
