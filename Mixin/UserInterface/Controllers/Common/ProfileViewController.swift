import UIKit
import MixinServices

class ProfileViewController: UIViewController {
    
    enum Size {
        
        case expanded
        case compressed
        case unavailable
        
        var opposite: Size {
            switch self {
            case .expanded:
                return .compressed
            case .compressed:
                return .expanded
            case .unavailable:
                return .unavailable
            }
        }
        
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
    
    @IBOutlet weak var hideContentConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuStackViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet var resizeRecognizer: UIPanGestureRecognizer!
    
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
    
    var size = Size.compressed
    var sizeAnimator: UIViewPropertyAnimator?
    var isResizeGestureEnabled = true {
        didSet {
            resizeRecognizerDelegate.isEnabled = isResizeGestureEnabled
        }
    }
    
    weak var descriptionViewIfLoaded: ProfileDescriptionView?
    weak var shortcutViewIfLoaded: ProfileShortcutView?
    
    var conversationId: String {
        return ""
    }
    
    var isMuted: Bool {
        return false
    }
    
    private lazy var resizeRecognizerDelegate = ResizeRecognizerDelegate(scrollView: scrollView)
    
    private var menuItemGroups = [[ProfileMenuItem]]()
    private var reusableMenuItemViews = Set<ProfileMenuItemView>()
    
    private weak var editNameController: UIAlertController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resizeRecognizer.delegate = resizeRecognizerDelegate
        updateBottomInset()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        setNeedsSizeAppearanceUpdated(size: size)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateBottomInset()
        updatePreferredContentSizeHeight(size: size)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        DispatchQueue.main.async {
            self.updatePreferredContentSizeHeight(size: self.size)
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func previewAvatarAction(_ sender: Any) {
        
    }
    
    @IBAction func changeSizeAction(_ recognizer: UIPanGestureRecognizer) {
        guard size != .unavailable, let superview = view.superview else {
            return
        }
        switch recognizer.state {
        case .began:
            scrollView.isScrollEnabled = false
            size = size.opposite
            let animator = makeSizeAnimator(destination: size)
            animator.pauseAnimation()
            sizeAnimator = animator
        case .changed:
            if let animator = sizeAnimator {
                let translation = recognizer.translation(in: superview)
                var fractionComplete = translation.y / (superview.bounds.height - preferredContentHeight(forSize: .compressed))
                if size == .expanded {
                    fractionComplete *= -1
                }
                animator.fractionComplete = fractionComplete
            }
        case .ended:
            if let animator = sizeAnimator {
                let locationAboveBegan = recognizer.translation(in: superview).y <= 0
                let isGoingUp = recognizer.velocity(in: superview).y <= 0
                let locationUnderBegan = recognizer.translation(in: superview).y >= 0
                let isGoingDown = recognizer.velocity(in: superview).y >= 0
                let shouldExpand = size == .expanded
                    && ((locationAboveBegan && isGoingUp) || isGoingUp)
                let shouldCompress = size == .compressed
                    && ((locationUnderBegan && isGoingDown) || isGoingDown)
                let shouldReverse = !shouldExpand && !shouldCompress
                let completionSize = shouldReverse ? size.opposite : size
                animator.isReversed = shouldReverse
                animator.addCompletion { (position) in
                    self.size = completionSize
                    self.updatePreferredContentSizeHeight(size: completionSize)
                    self.setNeedsSizeAppearanceUpdated(size: completionSize)
                    self.sizeAnimator = nil
                    recognizer.isEnabled = true
                }
                recognizer.isEnabled = false
                animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            }
        default:
            break
        }
    }
    
    func updatePreferredContentSizeHeight(size: Size) {
        guard !isBeingDismissed else {
            return
        }
        preferredContentSize.height = preferredContentHeight(forSize: size)
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
                WebViewController.presentInstance(with: .init(conversationId: conversationId, initialUrl: url), asChildOf: parent)
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
        let alert = UIAlertController(title: R.string.localizable.group_menu_clear(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.group_menu_clear(), style: .destructive, handler: { (_) in
            self.dismiss(animated: true, completion: nil)
            DispatchQueue.global().async {
                MessageDAO.shared.clearChat(conversationId: conversationId)
                DispatchQueue.main.async {
                    showAutoHiddenHud(style: .notification, text: Localized.GROUP_CLEAR_SUCCESS)
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - Private works
extension ProfileViewController {
    
    private class ResizeRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
        
        var isEnabled = true
        
        private unowned var scrollView: UIScrollView!
        
        init(scrollView: UIScrollView) {
            self.scrollView = scrollView
            super.init()
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled else {
                return false
            }
            let canDragDown: Bool
            if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
                canDragDown = abs(scrollView.contentOffset.y) < 0.1 && recognizer.velocity(in: nil).y > 0
            } else {
                canDragDown = false
            }
            return !scrollView.isScrollEnabled || canDragDown
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
    }
    
    @objc private func updateEditNameController(_ textField: UITextField) {
        let textIsEmpty = textField.text?.isEmpty ?? true
        editNameController?.actions[1].isEnabled = !textIsEmpty
    }
    
    private func updateBottomInset() {
        if view.safeAreaInsets.bottom > 5 {
            scrollView.contentInset.bottom = 5
        } else {
            scrollView.contentInset.bottom = 30
        }
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
    
    private func setNeedsSizeAppearanceUpdated(size: Size) {
        let toggleSizeButton = shortcutViewIfLoaded?.toggleSizeButton
        switch size {
        case .expanded:
            menuStackView.alpha = 1
            toggleSizeButton?.transform = CGAffineTransform(scaleX: 1, y: -1)
            scrollView.isScrollEnabled = true
            scrollView.alwaysBounceVertical = true
        case .compressed:
            menuStackView.alpha = 0
            toggleSizeButton?.transform = .identity
            scrollView.contentOffset = .zero
            scrollView.isScrollEnabled = false
            scrollView.alwaysBounceVertical = false
        case .unavailable:
            scrollView.isScrollEnabled = true
            scrollView.alwaysBounceVertical = true
        }
    }
    
    private func preferredContentHeight(forSize size: Size) -> CGFloat {
        view.layoutIfNeeded()
        let window = AppDelegate.current.window
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        switch size {
        case .expanded, .unavailable:
            return maxHeight
        case .compressed:
            let point = CGPoint(x: 0, y: centerStackView.bounds.maxY)
            let contentHeight = centerStackView.convert(point, to: contentView).y + 6
            let height = titleViewHeightConstraint.constant + contentHeight + window.safeAreaInsets.bottom
            return min(maxHeight, height)
        }
    }
    
    private func makeSizeAnimator(destination: Size) -> UIViewPropertyAnimator {
        let overdamped = UISpringTimingParameters()
        let animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: overdamped)
        animator.addAnimations {
            self.updatePreferredContentSizeHeight(size: destination)
            self.setNeedsSizeAppearanceUpdated(size: destination)
            self.view.layoutIfNeeded()
        }
        return animator
    }
    
}
