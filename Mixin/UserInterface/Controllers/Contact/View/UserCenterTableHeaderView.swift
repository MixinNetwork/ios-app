import UIKit
import SDWebImage

final class UserCenterTableHeaderView: UIView {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var membershipImageView: SDAnimatedImageView!
    @IBOutlet weak var identityNumberLabel: IdentityNumberLabel!
    
    private weak var membershipButton: UIButton?
    
    func addMembershipButton(target: Any, action: Selector) {
        if let button = membershipButton {
            button.removeTarget(nil, action: nil, for: .allEvents)
            button.addTarget(target, action: action, for: .touchUpInside)
        } else {
            let button = UIButton()
            button.addTarget(target, action: action, for: .touchUpInside)
            addSubview(button)
            button.snp.makeConstraints { make in
                make.width.height.equalTo(30)
                make.center.equalTo(membershipImageView)
            }
            membershipButton = button
        }
    }
    
    func removeMembershipButton() {
        membershipButton?.removeFromSuperview()
    }
    
}
