import Foundation
import Bugsnag
import UserNotifications
import Firebase
import SafariServices
import Crashlytics
import WCDBSwift

extension UIApplication {

    class func appDelegate() -> AppDelegate  {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    static var homeContainerViewController: HomeContainerViewController? {
        return UIApplication.shared.keyWindow?.rootViewController as? HomeContainerViewController
    }
    
    static var homeNavigationController: HomeNavigationController? {
        return homeContainerViewController?.homeNavigationController
    }
    
    static var homeViewController: HomeViewController? {
        return homeNavigationController?.viewControllers.first as? HomeViewController
    }
    
    static func currentActivity() -> UIViewController? {
        return homeNavigationController?.visibleViewController
    }

    static func currentConversationId() -> String? {
        guard UIApplication.shared.applicationState == .active else {
            return nil
        }
        guard let lastVC = homeNavigationController?.viewControllers.last, let chatVC = lastVC as? ConversationViewController else {
            return nil
        }
        return chatVC.dataSource?.conversationId
    }

    static func logEvent(eventName: String, parameters: [String: Any]? = nil) {
        #if RELEASE
        Analytics.logEvent(eventName, parameters: parameters as? [String: NSObject])
        #endif
    }

    static func traceError(_ error: Swift.Error) {
        #if DEBUG
        print(error)
        #endif
        Bugsnag.notifyError(error)
        Crashlytics.sharedInstance().recordError(error)
    }

    static func traceErrorToFirebase(code: ReportErrorCode, userInfo: [String: Any]) {
        let error = NSError(domain: code.errorName, code: code.rawValue, userInfo: userInfo)
        Crashlytics.sharedInstance().recordError(error)
    }

    static func traceWCDBError(_ error: WCDBSwift.Error) {
        #if DEBUG
        print(error)
        #endif
        var userInfo = [String: Any]()
        userInfo["operationValue"] = error.operationValue ?? ""
        userInfo["extendedCode"] = error.extendedCode ?? ""
        userInfo["description"] = error.description
        userInfo["path"] = error.path ?? ""
        userInfo["message"] = error.message ?? ""
        if error.type == .sqlite && (error.code.value == 11 || error.code.value == 26) {
            UIApplication.traceError(code: ReportErrorCode.databaseCorrupted, userInfo: userInfo)
        } else {
            UIApplication.traceError(code: ReportErrorCode.databaseError, userInfo: userInfo)
        }
    }

    static func traceError(code: ReportErrorCode, userInfo: [String: Any]) {
        let error = NSError(domain: code.errorName, code: code.rawValue, userInfo: userInfo)
        Bugsnag.notifyError(error, block: { (report) in
            report.addMetadata(userInfo, toTabWithName: "Track")
        })
        Crashlytics.sharedInstance().recordError(error)
    }

    static func getTrackUserInfo() -> [String: Any] {
        var userInfo = [String: Any]()
        userInfo["didLogin"] = AccountAPI.shared.didLogin
        userInfo["lastUpdateOrInstallTime"] = CommonUserDefault.shared.lastUpdateOrInstallTime
        userInfo["clientTime"] = DateFormatter.filename.string(from: Date())
        return userInfo
    }

}

extension UIApplication {

    public static func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
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
            UIApplication.homeNavigationController?.present(SFSafariViewController(url: url), animated: true, completion: nil)
        } else if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            Bugsnag.notify(NSException(name: NSExceptionName(rawValue: "Unrecognized URL"), reason: nil, userInfo: ["URL": url.absoluteString]))
        }
    }
    
}

extension UIApplication {
    
    func setShortcutItemsEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            if enabled {
                UIApplication.shared.shortcutItems = [.wallet, .scanQrCode, .myQrCode]
            } else {
                UIApplication.shared.shortcutItems = nil
            }
        }
    }
    
}

extension UIApplicationShortcutItem {
    
    enum ItemType: String {
        case scanQrCode
        case wallet
        case myQrCode
    }
    
    static let scanQrCode = UIApplicationShortcutItem(type: ItemType.scanQrCode.rawValue,
                                                      localizedTitle: R.string.localizable.scan_qr_code(),
                                                      localizedSubtitle: nil,
                                                      icon: .init(templateImageName: "ic_shortcut_scan_qr_code"),
                                                      userInfo: nil)
    static let wallet = UIApplicationShortcutItem(type: ItemType.wallet.rawValue,
                                                  localizedTitle: R.string.localizable.wallet_title(),
                                                  localizedSubtitle: nil,
                                                  icon: .init(templateImageName: "ic_shortcut_wallet"),
                                                  userInfo: nil)
    static let myQrCode = UIApplicationShortcutItem(type: ItemType.myQrCode.rawValue,
                                                    localizedTitle: R.string.localizable.myqrcode_title(),
                                                    localizedSubtitle: nil,
                                                    icon: .init(templateImageName: "ic_shortcut_my_qr_code"),
                                                    userInfo: nil)
    
}
