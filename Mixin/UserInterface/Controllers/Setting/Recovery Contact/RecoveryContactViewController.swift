import UIKit
import MixinServices

final class RecoveryContactViewController: UIViewController {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var descriptionTextView: IntroTextView!
    
    private let user: User
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    init(user: User) {
        self.user = user
        let nib = R.nib.recoveryContactView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.view_emergency_contact()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_titlebar_info(),
            target: self,
            action: #selector(presentUserInfo(_:))
        )
        avatarImageView.setImage(with: user.avatarUrl ?? "",
                                 userId: user.userId,
                                 name: user.fullName ?? "")
        nameLabel.text = user.fullName
        idLabel.text = R.string.localizable.contact_mixin_id(user.identityNumber)
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
        let text = R.string.localizable.setting_emergency_desc()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: R.color.text_tertiary()!
        ]
        let str = NSMutableAttributedString(string: text, attributes: attrs)
        let linkRange = (text as NSString)
            .range(of: R.string.localizable.learn_more(), options: [.backwards, .caseInsensitive])
        if linkRange.location != NSNotFound && linkRange.length != 0 {
            str.addAttribute(.link, value: URL.emergencyContact, range: linkRange)
        }
        descriptionTextView.attributedText = str
    }
    
    @objc private func presentUserInfo(_ sender: Any) {
        let userItem = UserItem.createUser(from: user)
        let vc = UserProfileViewController(user: userItem)
        present(vc, animated: true, completion: nil)
    }
    
}
