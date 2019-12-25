import Foundation

#if canImport(Bugsnag)
import Bugsnag
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

#if canImport(Crashlytics)
import Crashlytics
#endif

public enum Reporter {
    
    public typealias UserInfo = [String: Any]
    
    public enum Event {
        case signUp
        case login
        case sendSticker
        case openApp
        
        var name: String {
            switch self {
            case .signUp:
                #if canImport(FirebaseAnalytics)
                return AnalyticsEventSignUp
                #else
                return "sign_up"
                #endif
            case .login:
                #if canImport(FirebaseAnalytics)
                return AnalyticsEventLogin
                #else
                return "login"
                #endif
            case .sendSticker:
                return "send_sticker"
            case .openApp:
                return "open_app"
            }
        }
    }
    
    public static var basicUserInfo: [String: Any] {
        return ["lastUpdateOrInstallTime": AppGroupUserDefaults.User.lastUpdateOrInstallDate,
                "clientTime": DateFormatter.filename.string(from: Date())]
    }
    
    public static func configure(bugsnagApiKey key: String?) {
        #if canImport(Bugsnag) && RELEASE
        if let key = key {
            Bugsnag.start(withApiKey: key)
        }
        #endif
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
    }
    
    public static func registerUserInformation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        #if canImport(Bugsnag)
        Bugsnag.configuration()?.setUser(account.user_id, withName: account.full_name , andEmail: account.identity_number)
        #endif
        #if canImport(Crashlytics)
        Crashlytics.sharedInstance().setUserIdentifier(account.user_id)
        Crashlytics.sharedInstance().setUserName(account.full_name)
        Crashlytics.sharedInstance().setUserEmail(account.identity_number)
        Crashlytics.sharedInstance().setObjectValue(Bundle.main.bundleIdentifier ?? "", forKey: "Package")
        #endif
    }
    
    public static func report(event: Event, userInfo: UserInfo? = nil) {
        #if RELEASE
        if isAppExtension {
            var content = "[Event] " + event.name
            if let userInfo = userInfo {
                content += ", userInfo: \(userInfo)"
            }
            write(content: content, to: .event)
        } else {
            #if canImport(FirebaseAnalytics)
            Analytics.logEvent(event.name, parameters: userInfo)
            #endif
        }
        #endif
    }
    
    public static func report(error: Error) {
        if isAppExtension {
            let content = "[Error] " + error.localizedDescription
            write(content: content, to: .error)
        } else {
            #if canImport(Bugsnag)
            Bugsnag.notifyError(error)
            #endif
            
            #if canImport(Firebase)
            Crashlytics.sharedInstance().recordError(error)
            #endif
        }
    }
    
    public static func reportErrorToFirebase(_ error: Error) {
        if isAppExtension {
            let content = "[Error] " + error.localizedDescription
            write(content: content, to: .firebaseOnlyError)
        } else {
            #if canImport(Crashlytics)
            Crashlytics.sharedInstance().recordError(error)
            #endif
        }
    }
    
    public static func uploadAndRemoveLocalReports() {
        
    }
    
}

extension Reporter {
    
    private enum Destination: String {
        case event
        case error
        case firebaseOnlyError = "fir_error"
    }
    
    private static func write(content: String, to destination: Destination) {
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            assertionFailure()
            return
        }
        let fileUrl = containerUrl
            .appendingPathComponent("report", isDirectory: true)
            .appendingPathComponent(destination.rawValue)
            .appendingPathExtension("txt")
        do {
            try content.write(to: fileUrl, atomically: true, encoding: .utf8)
        } catch {
            assertionFailure()
        }
    }
    
}
