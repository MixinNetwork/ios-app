import UIKit

final class BackgroundDismissablePopupPresentationController: PopupPresentationController {
    
    static let willDismissPresentedViewControllerNotification = Notification.Name("one.mixin.messenger.PopupPresentationController.WillDismissPresentedViewController")
    static let didDismissPresentedViewControllerNotification = Notification.Name("one.mixin.messenger.PopupPresentationController.DidDismissPresentedViewController")
    
    override func makeBackgroundView() -> UIView {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.alpha = 0
        button.addTarget(self, action: #selector(dismissPresentedViewController(sender:)), for: .touchUpInside)
        return button
    }
    
    @objc func dismissPresentedViewController(sender: Any) {
        NotificationCenter.default.post(name: Self.willDismissPresentedViewControllerNotification, object: self)
        presentingViewController.dismiss(animated: true) {
            NotificationCenter.default.post(name: Self.didDismissPresentedViewControllerNotification, object: self)
        }
    }
    
}
