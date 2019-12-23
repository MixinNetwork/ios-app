import Foundation

#if canImport(Bugsnag)
import Bugsnag
#endif

#if canImport(Firebase)
import Firebase
#endif

#if canImport(Crashlytics)
import Crashlytics
#endif

public enum Reporter {
    
    public typealias UserInfo = [String: Any]
    
    public enum Event {
        case fir(String)
        case sendSticker
        case openApp
        
        var name: String {
            switch self {
            case .fir(let name):
                return name
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
    
    public static func report(event: Event, userInfo: UserInfo? = nil) {
        #if RELEASE
        if isAppExtension {
            var content = "[Event] " + event
            if let userInfo = userInfo {
                content += ", userInfo: \(userInfo)"
            }
            write(content: content, to: .event)
        } else {
            #if canImport(Firebase)
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
            #if canImport(Firebase)
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
