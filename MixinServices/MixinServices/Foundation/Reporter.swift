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
        case cancelAudioRecording
        case swap
        
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
            case .swap:
                return "swap"
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
        
        AppCenter.start(withAppSecret: key, services: [Analytics.self, Crashes.self])
        
        if !isAppExtension, Crashes.hasCrashedInLastSession, let report = Crashes.lastSessionCrashReport {
            Logger.general.info(category: "LastCrash", message: "Signal: \(report.signal), exception: \(report.exceptionName ?? "(null)"), reason: \(report.exceptionReason ?? "(null)")")
        }
    }

    open func registerUserInformation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        AppCenter.userId = account.userID
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
