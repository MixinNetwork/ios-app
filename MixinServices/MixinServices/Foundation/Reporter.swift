import Foundation
import Bugsnag
import FirebaseCore
import FirebaseAnalytics
import Crashlytics

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
                return AnalyticsEventSignUp
            case .login:
                return AnalyticsEventLogin
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
        #if RELEASE
        if let key = key {
            Bugsnag.start(withApiKey: key)
        }
        #endif
        FirebaseApp.configure()
    }
    
    public static func registerUserInformation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        Bugsnag.configuration()?.setUser(account.user_id, withName: account.full_name , andEmail: account.identity_number)
        Crashlytics.sharedInstance().setUserIdentifier(account.user_id)
        Crashlytics.sharedInstance().setUserName(account.full_name)
        Crashlytics.sharedInstance().setUserEmail(account.identity_number)
        Crashlytics.sharedInstance().setObjectValue(Bundle.main.bundleIdentifier ?? "", forKey: "Package")
    }
    
    public static func report(event: Event, userInfo: UserInfo? = nil) {
        if isAppExtension {
            var content = "[Event] " + event.name
            if let userInfo = userInfo {
                content += ", userInfo: \(userInfo)"
            }
            write(content: content, to: .event)
        } else {
            Analytics.logEvent(event.name, parameters: userInfo)
        }
    }
    
    public static func report(error: Error) {
        if isAppExtension {
            let content = "[Error] " + error.localizedDescription
            write(content: content, to: .error)
        } else {
            Bugsnag.notifyError(error)
            Crashlytics.sharedInstance().recordError(error)
        }
    }
    
    public static func reportErrorToFirebase(_ error: Error) {
        if isAppExtension {
            let content = "[Error] " + error.localizedDescription
            write(content: content, to: .firebaseOnlyError)
        } else {
            Crashlytics.sharedInstance().recordError(error)
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
        let reportContainerUrl = containerUrl.appendingPathComponent("Report", isDirectory: true)
        do {
            if !FileManager.default.fileExists(atPath: reportContainerUrl.path, isDirectory: nil) {
                try FileManager.default.createDirectory(at: reportContainerUrl, withIntermediateDirectories: true, attributes: nil)
            }
            let fileUrl = reportContainerUrl
                .appendingPathComponent(destination.rawValue, isDirectory: false)
                .appendingPathExtension("txt")
            try content.write(to: fileUrl, atomically: true, encoding: .utf8)
        } catch {
            assertionFailure()
        }
    }
    
}
