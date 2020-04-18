import UIKit
import MixinServices

class ProfileViewController: ResizablePopupViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var scrollViewContentView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var subtitleLabel: IdentityNumberLabel!
    @IBOutlet weak var centerStackView: UIStackView!
    @IBOutlet weak var menuStackView: UIStackView!
    
    @IBOutlet weak var hideContentConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuStackViewTopConstraint: NSLayoutConstraint!
    
    lazy var relationshipView = ProfileRelationshipView()
    lazy var descriptionView: ProfileDescriptionView = {
        let view = ProfileDescriptionView()
        view.label.delegate = self
        view.clipsToBounds = true
        descriptionViewIfLoaded = view
        return view
    }()
    lazy var shortcutView: ProfileShortcutView = {
        let view = ProfileShortcutView()
        shortcutViewIfLoaded = view
        return view
    }()
    lazy var circleItemView: CircleProfileMenuItemView = {
        let view = CircleProfileMenuItemView()
        view.button.addTarget(self, action: #selector(editCircle), for: .touchUpInside)
        return view
    }()
    
    weak var descriptionViewIfLoaded: ProfileDescriptionView?
    weak var shortcutViewIfLoaded: ProfileShortcutView?
    
    override var resizableScrollView: UIScrollView {
        scrollView
    }
    
    var conversationId: String {
        return ""
    }
    
    var conversationName: String {
        return ""
    }
    
    var isMuted: Bool {
        return false
    }
    
    private lazy var resizeRecognizerDelegate = PopupResizeGestureCoordinator(scrollView: resizableScrollView)
    
    private var menuItemGroups = [[ProfileMenuItem]]()
    private var reusableMenuItemViews = Set<ProfileMenuItemView>()
    private var subordinateCircles: [CircleItem]? {
        didSet {
            circleItemView.names = subordinateCircles?.map(\.name) ?? []
        }
    }
    
    private weak var editNameController: UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.addGestureRecognizer(resizeRecognizer)
        resizeRecognizer.delegate = resizeRecognizerDelegate
    }
    
    override func setNeedsSizeAppearanceUpdated(size: Size) {
        super.setNeedsSizeAppearanceUpdated(size: size)
        let toggleSizeButton = shortcutViewIfLoaded?.toggleSizeButton
        switch size {
        case .expanded:
            menuStackView.alpha = 1
            toggleSizeButton?.transform = CGAffineTransform(scaleX: 1, y: -1)
        case .compressed:
            menuStackView.alpha = 0
            toggleSizeButton?.transform = .identity
        case .unavailable:
            break
        }
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        view.layoutIfNeeded()
        let window = AppDelegate.current.mainWindow
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        switch size {
        case .expanded, .unavailable:
            return maxHeight
        case .compressed:
            let point = CGPoint(x: 0, y: centerStackView.bounds.maxY)
            let contentHeight = centerStackView.convert(point, to: scrollViewContentView).y + 6
            let height = titleViewHeightConstraint.constant + contentHeight + window.safeAreaInsets.bottom
            return min(maxHeight, height)
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func previewAvatarAction(_ sender: Any) {
        
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
    
    func reloadMenu(groups: [[ProfileMenuItem]]) {
        let removeFromSuperview = { (view: UIView) in
            view.removeFromSuperview()
        }
        reusableMenuItemViews.forEach(removeFromSuperview)
        menuStackView.subviews.forEach(removeFromSuperview)
        
        self.menuItemGroups = groups
        for group in groups {
            let stackView = UIStackView()
            stackView.axis = .vertical
            for (index, item) in group.enumerated() {
                let view = dequeueReusableMenuItemView()
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
    
    func reloadCircles(conversationId: String, userId: String?) {
        DispatchQueue.global().async { [weak self] in
            let circles = CircleDAO.shared.circles(of: conversationId, userId: userId)
            DispatchQueue.main.sync {
                self?.subordinateCircles = circles
            }
        }
    }
    
}

// MARK: - CoreTextLabelDelegate
extension ProfileViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        let conversationId = self.conversationId
        dismiss(animated: true) {
            guard let parent = UIApplication.homeNavigationController?.visibleViewController else {
                return
            }
            guard !self.openUrlOutsideApplication(url) else {
                return
            }
            if !UrlWindow.checkUrl(url: url) {
                MixinWebViewController.presentInstance(with: .init(conversationId: conversationId, initialUrl: url), asChildOf: parent)
            }
        }
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_OPEN_URL, style: .default, handler: { [weak self] (_) in
            self?.coreTextLabel(label, didSelectURL: url)
        }))
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_MENU_COPY, style: .default, handler: { (_) in
            UIPasteboard.general.string = url.absoluteString
            showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - Actions
extension ProfileViewController {
    
    @objc func toggleSize(_ sender: UIButton) {
        size = size.opposite
        let animator = makeSizeAnimator(destination: size)
        animator.startAnimation()
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
        let conversationId = self.conversationId
        let title: String
        if self is GroupProfileViewController {
            title = R.string.localizable.profile_clear_group_chat_hint(conversationName)
        } else {
            title = R.string.localizable.profile_clear_contact_chat_hint(conversationName)
        }
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.group_menu_clear(), style: .destructive, handler: { (_) in
            self.dismiss(animated: true, completion: nil)
            DispatchQueue.global().async {
                ConversationDAO.shared.clearChat(conversationId: conversationId)
                DispatchQueue.main.async {
                    showAutoHiddenHud(style: .notification, text: Localized.GROUP_CLEAR_SUCCESS)
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func editCircle() {
        let circles = subordinateCircles ?? []
        let ownerId = (self as? UserProfileViewController)?.user.userId
        let vc = ConversationCircleEditorViewController.instance(name: conversationName,
                                                                 conversationId: conversationId,
                                                                 ownerId: ownerId,
                                                                 subordinateCircles: circles)
        dismissAndPush(vc)
    }
    
}

// MARK: - Private works
extension ProfileViewController {
    
    @objc private func updateEditNameController(_ textField: UITextField) {
        let textIsEmpty = textField.text?.isEmpty ?? true
        editNameController?.actions[1].isEnabled = !textIsEmpty
    }
    
    private func dequeueReusableMenuItemView() -> ProfileMenuItemView {
        if let view = reusableMenuItemViews.first(where: { $0.superview == nil }) {
            return view
        } else {
            let view = ProfileMenuItemView()
            reusableMenuItemViews.insert(view)
            return view
        }
    }
    
}
