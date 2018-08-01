import Foundation
import Bugsnag
import UserNotifications
import Firebase
import AudioToolbox
import SafariServices

extension UIApplication {

    class func appDelegate() -> AppDelegate  {
        return UIApplication.shared.delegate as! AppDelegate
    }

    static func rootNavigationController() -> UINavigationController? {
        return UIApplication.shared.keyWindow?.rootViewController as? UINavigationController
    }

    static func currentActivity() -> UIViewController? {
        return rootNavigationController()?.visibleViewController
    }

    static func currentConversationId() -> String? {
        guard let lastVC = rootNavigationController()?.viewControllers.last, let chatVC = lastVC as? ConversationViewController else {
            return nil
        }
        return chatVC.dataSource?.conversationId
    }

    static func logEvent(eventName: String, parameters: [String: Any]? = nil) {
        #if RELEASE
        Analytics.logEvent(eventName, parameters: parameters as? [String: NSObject])
        #endif
    }

    static func trackError(_ category: String, action: String, userInfo aUserInfo: [AnyHashable: Any]? = nil) {
        #if RELEASE
        if let aUserInfo = aUserInfo {
            Bugsnag.notify(NSException(name: NSExceptionName(rawValue: category), reason: action, userInfo: nil)) {
                (report) -> Void in
                report.addMetadata(aUserInfo, toTabWithName: "Track")
            }
        } else {
            Bugsnag.notify(NSException(name: NSExceptionName(rawValue: category), reason: action, userInfo: nil))
        }
        #endif
    }

    static func getTrackUserInfo() -> [AnyHashable: Any] {
        var userInfo = [AnyHashable: Any]()
        userInfo["didLogin"] = AccountAPI.shared.didLogin
        if let account = AccountAPI.shared.account {
            userInfo["full_name"] = account.full_name
            userInfo["identity_number"] = account.identity_number
        }
        userInfo["lastUpdateOrInstallTime"] = CommonUserDefault.shared.lastUpdateOrInstallTime
        userInfo["clientTime"] = DateFormatter.filename.string(from: Date())
        return userInfo
    }

}

extension UIApplication {

    static func playTakePhotoSound() {
        AudioServicesPlaySystemSound(1108)
    }

    static func playPeekSound() {
        AudioServicesPlaySystemSound(1519)
    }

}

extension UIApplication {

    public static func openAppSettings() {
        guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
    }

    public func openURL(url: String) {
        guard let url = URL(string: url) else {
            return
        }
        openURL(url: url)
    }

    public func openURL(url: URL) {
        if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.rootNavigationController()?.present(SFSafariViewController(url: url), animated: true, completion: nil)
        } else if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            Bugsnag.notify(NSException(name: NSExceptionName(rawValue: "Unrecognized URL"), reason: nil, userInfo: ["URL": url.absoluteString]))
        }
    }
    
}

extension UIApplication {

    static func isJailbreak() -> Bool {
        if FileManager.default.fileExists(atPath: "/Applications/Cydia.app") ||
            FileManager.default.fileExists(atPath: "/Library/MobileSubstrate/MobileSubstrate.dylib") ||
            FileManager.default.fileExists(atPath: "/bin/bash") ||
            FileManager.default.fileExists(atPath: "/usr/bin/sshd") ||
            FileManager.default.fileExists(atPath: "/usr/sbin/sshd") ||
            FileManager.default.fileExists(atPath: "/etc/apt") ||
            FileManager.default.fileExists(atPath: "/private/var/lib/apt") ||
            FileManager.default.fileExists(atPath: "/private/var/lib/cydia") ||
            FileManager.default.fileExists(atPath: "/private/var/stash") ||
            UIApplication.shared.canOpenURL(URL(string:"cydia://package/com.example.package")!) {
            return true
        }

        let stringToWrite = "Jailbreak Test"
        do
        {
            try stringToWrite.write(toFile:"/private/JailbreakTest.txt", atomically: true, encoding:.utf8)
            try? FileManager.default.removeItem(atPath: "/private/JailbreakTest.txt")
            return true
        } catch {
            return false
        }
    }

}
