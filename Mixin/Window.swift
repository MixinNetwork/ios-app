import UIKit

class Window: UIWindow {
    
    private var dismissMenuResponder: UIButton?
    
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(menuControllerWillHideMenu(_:)),
                                               name: UIMenuController.willHideMenuNotification,
                                               object: nil)
    }
    
    @objc private func dismissMenu(_ sender: Any) {
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }
    
    @objc private func menuControllerWillHideMenu(_ notification: Notification) {
        dismissMenuResponder?.removeFromSuperview()
        dismissMenuResponder = nil
        NotificationCenter.default.removeObserver(self,
                                                  name: UIMenuController.willHideMenuNotification,
                                                  object: nil)
    }
    
}
