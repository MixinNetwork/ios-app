import UIKit
import MixinServices

final class ViewEmergencyContactViewController: UIViewController {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var descriptionTextView: IntroTextView!
    
    private var user: User!
    
    class func instance(user: User) -> UIViewController {
        let vc = R.storyboard.setting.view_emergency_contact()!
        vc.user = user
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.emergency_view())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        avatarImageView.setImage(with: user.avatarUrl ?? "",
                                 userId: user.userId,
                                 name: user.fullName ?? "")
        nameLabel.text = user.fullName
        idLabel.text = Localized.PROFILE_MIXIN_ID(id: user.identityNumber)
        updateDescription()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        updateDescription()
    }
    
    private func updateDescription() {
        let text = R.string.localizable.emergency_tip_after()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UIColor.accessoryText
        ]
        let str = NSMutableAttributedString(string: text, attributes: attrs)
        let linkRange = (text as NSString)
            .range(of: R.string.localizable.emergency_tip_link(), options: .backwards)
        if linkRange.location != NSNotFound && linkRange.length != 0 {
            str.addAttribute(.link, value: URL.emergencyContact, range: linkRange)
        }
        descriptionTextView.attributedText = str
    }
    
}

extension ViewEmergencyContactViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let userItem = UserItem.createUser(from: user)
        let vc = UserProfileViewController(user: userItem)
        present(vc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_titlebar_info()
    }
    
}
