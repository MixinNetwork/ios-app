import Foundation
import SDWebImage

class UserWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!
    
    var userViewPopupView: UIView?

    private let userView = UserView.instance()

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(userView)
        userView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
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

    @discardableResult
    func updateUser(user: UserItem, animated: Bool = false, refreshUser: Bool = true) -> UserWindow {
        userView.updateUser(user: user, animated: animated, refreshUser: refreshUser, superView: self)
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
