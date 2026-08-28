import Foundation
import SafariServices
import MixinServices

extension UIApplication {
    
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
    
    var firstWindowScene: UIWindowScene? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
    
    var homeContainerViewController: HomeContainerViewController? {
        firstWindowScene?.keyWindow?.rootViewController as? HomeContainerViewController
    }
    
    var homeNavigationController: HomeNavigationController? {
        homeContainerViewController?.homeNavigationController
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
    
    func currentConversationId() -> String? {
        return currentConversationViewController()?.conversationId
    }
    
    func currentConversationViewController() -> ConversationViewController? {
        guard UIApplication.shared.applicationState == .active else {
            return nil
        }
        guard let lastVC = homeNavigationController?.viewControllers.last else {
            return nil
        }
        return lastVC as? ConversationViewController
    }
    
}

extension UIApplication {
    
    public func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
    }
    
    public func openNotificationSettings() {
        let url = if #available(iOS 16.0, *)  {
            URL(string: UIApplication.openNotificationSettingsURLString)
        } else {
            URL(string: UIApplication.openSettingsURLString)
        }
        if let url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    public func openURL(url: String) {
        guard let url = URL(string: url) else {
            return
        }
        openURL(url: url)
    }

    public func openURL(url: URL) {
        if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            homeNavigationController?.present(SFSafariViewController(url: url), animated: true, completion: nil)
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
