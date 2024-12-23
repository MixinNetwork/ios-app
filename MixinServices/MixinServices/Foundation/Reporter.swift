import Foundation
import Sentry

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
        guard
            let path = Bundle.main.path(forResource: "Mixin-Keys", ofType: "plist"),
            let keys = NSDictionary(contentsOfFile: path) as? [String: Any],
            let sentryKey = keys["Sentry"] as? String
        else {
            return
        }
        
        SentrySDK.start { options in
            options.dsn = sentryKey
            options.enablePerformanceV2 = true
#if DEBUG
            options.tracesSampleRate = 1.0
#else
            options.tracesSampleRate = 0.1
#endif
        }
    }
    
    open func registerUserInformation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        SentrySDK.setUser(Sentry.User(userId: account.userID))
    }
    
    open func report(event: Event, userInfo: UserInfo? = nil) {
        let event = Sentry.Event(level: .info)
        event.extra = userInfo
        SentrySDK.capture(event: event)
    }

    open func report(error: MixinAPIError) {
        SentrySDK.capture(error: error)
    }

    open func report(error: Error, userInfo: UserInfo? = nil) {
        if let info = userInfo {
            let event = Sentry.Event(level: .error)
            event.extra = userInfo
            SentrySDK.capture(event: event)
        } else {
            SentrySDK.capture(error: error)
        }
    }
}
