import UIKit

class ProfileViewController: UIViewController {
    
    enum Size {
        case expanded
        case compressed
        case unavailable
    }
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var subtitleLabel: IdentityNumberLabel!
    @IBOutlet weak var centerStackView: UIStackView!
    @IBOutlet weak var menuStackView: UIStackView!
    
    @IBOutlet weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuStackViewTopConstraint: NSLayoutConstraint!
    
    lazy var relationshipView = ProfileRelationshipView()
    lazy var descriptionView = ProfileDescriptionView()
    lazy var shortcutView = ProfileShortcutView()
    
    var size = Size.compressed
    
    var conversationId: String {
        return ""
    }
    
    var isMuted: Bool {
        return false
    }
    
    var menuItemGroups = [[ProfileMenuItem]]() {
        didSet {
            layoutMenuItems()
        }
    }
    
    private weak var editNameController: UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateBottomInset()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        setNeedsSizeAppearanceUpdated(sender: self)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateBottomInset()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let window = AppDelegate.current.window
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        let contentHeight: CGFloat
        switch size {
        case .expanded, .unavailable:
            contentHeight = contentView.frame.height
        case .compressed:
            let point = CGPoint(x: 0, y: centerStackView.bounds.maxY)
            contentHeight = centerStackView.convert(point, to: contentView).y
        }
        let height = titleViewHeightConstraint.constant + contentHeight + window.safeAreaInsets.bottom
        preferredContentSize.height = min(maxHeight, height)
    }
    
    func dismissAndPresent(_ viewController: UIViewController) {
        let presenting = presentingViewController
        dismiss(animated: true) {
            presenting?.present(viewController, animated: true, completion: nil)
        }
    }
    
    func dismissAndPush(_ viewController: UIViewController) {
        dismiss(animated: true) {
            UIApplication.homeNavigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    func presentEditNameController(title: String, text: String, placeholder: String, onChange: @escaping (String) -> Void) {
        var nameTextField: UITextField!
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        controller.addTextField { (textField) in
            textField.text = text
            textField.placeholder = placeholder
            textField.addTarget(self, action: #selector(self.updateEditNameController(_:)), for: .editingChanged)
            nameTextField = textField
        }
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CHANGE, style: .default, handler: { _ in
            guard let text = nameTextField.text else {
                return
            }
            onChange(text)
        }))
        present(controller, animated: true, completion: nil)
        editNameController = controller
    }
    
    func updateMuteInterval(inSeconds interval: Int64) {
        
    }
    
}

// MARK: - Actions
extension ProfileViewController {
    
    @objc func toggleSize(_ sender: UIButton) {
        switch size {
        case .expanded:
            size = .compressed
        case .compressed:
            size = .expanded
        case .unavailable:
            break
        }
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.updatePreferredContentSizeHeight()
            self.setNeedsSizeAppearanceUpdated(sender: sender)
        })
    }
    
    @objc func mute() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_8H, style: .default, handler: { (_) in
            self.updateMuteInterval(inSeconds: MuteInterval.eightHours)
        }))
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1WEEK, style: .default, handler: { (_) in
            self.updateMuteInterval(inSeconds: MuteInterval.oneWeek)
        }))
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1YEAR, style: .default, handler: { (_) in
            self.updateMuteInterval(inSeconds: MuteInterval.oneYear)
        }))
        if isMuted {
            alert.addAction(UIAlertAction(title: R.string.localizable.profile_unmute(), style: .default, handler: { (_) in
                self.updateMuteInterval(inSeconds: MuteInterval.none)
            }))
        }
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func clearChat() {
        dismiss(animated: true, completion: nil)
        let conversationId = self.conversationId
        DispatchQueue.global().async {
            MessageDAO.shared.clearChat(conversationId: conversationId)
            DispatchQueue.main.async {
                showAutoHiddenHud(style: .notification, text: Localized.GROUP_CLEAR_SUCCESS)
            }
        }
    }
    
}

// MARK: - Private works
extension ProfileViewController {
    
    @objc private func updateEditNameController(_ textField: UITextField) {
        let textIsEmpty = textField.text?.isEmpty ?? true
        editNameController?.actions[1].isEnabled = !textIsEmpty
    }
    
    private func setNeedsSizeAppearanceUpdated(sender: Any) {
        switch size {
        case .expanded:
            menuStackView.alpha = 1
            (sender as? UIButton)?.transform = .init(rotationAngle: .pi)
            scrollView.isScrollEnabled = true
        case .compressed:
            menuStackView.alpha = 0
            (sender as? UIButton)?.transform = .identity
            scrollView.contentOffset = .zero
            scrollView.isScrollEnabled = false
        case .unavailable:
            break
        }
    }
    
    private func updateBottomInset() {
        if view.safeAreaInsets.bottom > 5 {
            scrollView.contentInset.bottom = 5
        } else {
            scrollView.contentInset.bottom = 10
        }
    }
    
    private func layoutMenuItems() {
        menuStackView.subviews.forEach { (view) in
            view.removeFromSuperview()
        }
        for group in menuItemGroups {
            let stackView = UIStackView()
            stackView.axis = .vertical
            for (index, item) in group.enumerated() {
                let view = ProfileMenuItemView()
                view.item = item
                view.target = self
                var maskedCorners: CACornerMask = []
                if index == group.startIndex {
                    maskedCorners.formUnion([.layerMinXMinYCorner, .layerMaxXMinYCorner])
                }
                if index == group.endIndex - 1 {
                    maskedCorners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
                }
                view.button.layer.maskedCorners = maskedCorners
                stackView.addArrangedSubview(view)
            }
            menuStackView.addArrangedSubview(stackView)
        }
    }
    
}
