import Foundation
import SDWebImage

class UserWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!
    
    var userViewPopupView: UIView?

    private let userView = UserView.instance()
    private var onDissmisCallback: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(userView)
        userView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    func setDismissCallback(callback: @escaping () -> Void) {
        onDissmisCallback = callback
    }

    override func dismissPopupControllerAnimated() {
        if popupView is UserView.AvatarPreviewImageView {
            isShowing = false
            UIView.animate(withDuration: 0.25, animations: {
                self.alpha = 0
                self.popupView.bounds = .zero
            }, completion: { (_) in
                self.popupView.removeFromSuperview()
                if let popupView = self.userViewPopupView {
                    self.popupView = popupView
                }
                self.userView.avatarImageView.isHidden = false
                self.contentBottomConstraint.constant = 0
                self.layoutIfNeeded()
            })
        } else {
            dismissView()
        }
    }

    override func dismissView() {
        self.alpha = 1.0
        isShowing = false
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.alpha = 0
            self.popupView.center = self.getAnimationStartPoint()
        }, completion: { _ in
            if let popupView = self.userViewPopupView {
                self.popupView.removeFromSuperview()
                self.popupView = popupView
                self.userViewPopupView = nil
                self.userView.avatarImageView.isHidden = false
            }
            self.contentBottomConstraint.constant = 0
            self.layoutIfNeeded()
        })
        onDissmisCallback?()
    }

    @discardableResult
    func updateUser(user: UserItem, refreshUser: Bool = true) -> UserWindow {
        userView.updateUser(user: user, refreshUser: refreshUser, superView: self)
        return self
    }

    class func instance() -> UserWindow {
        let window = Bundle.main.loadNibNamed("UserWindow", owner: nil, options: nil)?.first as! UserWindow
        if let windowFrame = UIApplication.shared.keyWindow?.bounds {
            window.frame = windowFrame
        }
        return window
    }
    
}
