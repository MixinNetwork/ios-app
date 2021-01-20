import Foundation
import SafariServices
import MixinServices

extension UIApplication {
    
    static var homeContainerViewController: HomeContainerViewController? {
        return AppDelegate.current.mainWindow.rootViewController as? HomeContainerViewController
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
        return currentConversationViewController()?.conversationId
    }

    static func currentConversationViewController() -> ConversationViewController? {
        guard UIApplication.shared.applicationState == .active else {
            return nil
        }
        guard let lastVC = homeNavigationController?.viewControllers.last else {
            return nil
        }
        return lastVC as? ConversationViewController
    }

    static var isApplicationActive: Bool {
        if Thread.isMainThread {
            return UIApplication.shared.applicationState == .active
        } else {
            var isActive = false
            DispatchQueue.main.sync {
                isActive = UIApplication.shared.applicationState == .active
            }
            return isActive
        }
    }

    var applicationStateString: String {
        switch applicationState {
        case .active:
            return "active"
        case .background:
            return "background"
        case .inactive:
            return "inactive"
        @unknown default:
            return "unknown"
        }
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
            let error = MixinError.unrecognizedUrl(url)
            reporter.report(error: error)
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
