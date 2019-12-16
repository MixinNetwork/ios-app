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
    
    public static func report(event: Event, userInfo: UserInfo? = nil) {
        #if RELEASE
        if isAppExtension {
            write(event: event.name, userInfo: userInfo)
        } else {
            #if canImport(Firebase)
            Analytics.logEvent(event.name, parameters: userInfo)
            #endif
        }
        #endif
    }
    
    private static func write(event: String, userInfo: UserInfo? = nil) {
        var content = "[Event] " + event
        if let userInfo = userInfo {
            content += ", userInfo: \(userInfo)"
        }
        write(content: content, to: "event")
    }
    
    private static func write(content: String, to destination: String) {
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            assertionFailure()
            return
        }
        let fileUrl = containerUrl
            .appendingPathComponent("report", isDirectory: true)
            .appendingPathComponent(destination)
            .appendingPathExtension("txt")
        do {
            try content.write(to: fileUrl, atomically: true, encoding: .utf8)
        } catch {
            assertionFailure()
        }
    }
    
}
