import Foundation
import SDWebImage

class UserWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!

    private let userView = UserView.instance()

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(userView)
        userView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    override func dismissPopupControllerAnimated() {
        dismissView()
    }

    @discardableResult
    func updateUser(user: UserItem, animated: Bool = false, refreshUser: Bool = true) -> UserWindow {
        userView.updateUser(user: user, animated: animated, refreshUser: refreshUser, superView: self)
        return self
    }

    class func instance() -> UserWindow {
        return Bundle.main.loadNibNamed("UserWindow", owner: nil, options: nil)?.first as! UserWindow
    }
}
