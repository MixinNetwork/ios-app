import UIKit
import MixinServices

class Window: UIWindow {
    
    private var dismissMenuResponder: UIButton?
    
    private var notificationCenter: NotificationCenter {
        .default
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        observeUserInterfaceStyleChangeNotification()
        updateUserInterfaceStyle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeUserInterfaceStyleChangeNotification()
        updateUserInterfaceStyle()
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    func addDismissMenuResponder() {
        guard dismissMenuResponder == nil else {
            return
        }
        let responder = UIButton()
        responder.backgroundColor = .clear
        responder.frame = bounds
        responder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        responder.addTarget(self, action: #selector(dismissMenu(_:)), for: .touchUpInside)
        addSubview(responder)
        self.dismissMenuResponder = responder
        notificationCenter.addObserver(self,
                                       selector: #selector(menuControllerWillHideMenu(_:)),
                                       name: UIMenuController.willHideMenuNotification,
                                       object: nil)
    }
    
    @objc private func dismissMenu(_ sender: Any) {
        UIMenuController.shared.hideMenu()
    }
    
    @objc private func menuControllerWillHideMenu(_ notification: Notification) {
        dismissMenuResponder?.removeFromSuperview()
        dismissMenuResponder = nil
        notificationCenter.removeObserver(self,
                                          name: UIMenuController.willHideMenuNotification,
                                          object: nil)
    }
    
    @objc private func updateUserInterfaceStyle() {
        overrideUserInterfaceStyle = AppGroupUserDefaults.User.userInterfaceStyle
    }
    
    private func observeUserInterfaceStyleChangeNotification() {
        let notifications = [
            AppGroupUserDefaults.User.didChangeUserInterfaceStyleNotification,
            LoginManager.accountDidChangeNotification,
            LoginManager.didLogoutNotification
        ]
        for notification in notifications {
            notificationCenter.addObserver(self,
                                           selector: #selector(updateUserInterfaceStyle),
                                           name: notification,
                                           object: nil)
        }
    }
    
}
