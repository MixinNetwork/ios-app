import UIKit

class ConversationInputViewController: UIViewController {
    
    @IBOutlet weak var deleteChatButton: BusyButton!
    @IBOutlet weak var unblockButton: BusyButton!
    @IBOutlet weak var inputBarView: UIView!
    @IBOutlet weak var extensionsSwitch: ConversationExtensionSwitch!
    @IBOutlet weak var inputTextView: ConversationInputTextView!
    @IBOutlet weak var inputTextViewRightAccessoryView: UIView!
    @IBOutlet weak var stickersButton: UIButton!
    @IBOutlet weak var keyboardButton: UIButton!
    @IBOutlet weak var appButton: UIButton!
    @IBOutlet weak var rightActionsStackView: UIStackView!
    @IBOutlet weak var photosButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var audioInputContainerView: UIView!
    @IBOutlet weak var customInputContainerView: UIView!
    
    @IBOutlet weak var beginEditingInputTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var beginEditingRightActionsStackLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingInputTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingRightActionsStackTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var audioInputContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var customInputContainerHeightConstraint: NSLayoutConstraint!
    
    private let keyboardManager = ConversationKeyboardManager()
    
    private lazy var extensionViewController = R.storyboard.chat.extension()!
    private lazy var stickersViewController = R.storyboard.chat.stickerInput()!
    private lazy var photoViewController = R.storyboard.chat.photo()!
    private lazy var audioViewController = R.storyboard.chat.audioInput()!
    
    private var reportHeightChangeWhenKeyboardFrameChanges = true
    private var customInputViewController: UIViewController? {
        didSet {
            if let old = oldValue {
                old.willMove(toParent: nil)
                old.view.removeFromSuperview()
                old.removeFromParent()
            }
            if let new = customInputViewController {
                addChild(new)
                customInputContainerView.addSubview(new.view)
                new.view.snp.makeConstraints({ (make) in
                    make.edges.equalToSuperview()
                })
                new.didMove(toParent: self)
            }
        }
    }
    
    private var conversationViewController: ConversationViewController {
        return parent as! ConversationViewController
    }
    
    private var dataSource: ConversationDataSource {
        return conversationViewController.dataSource
    }
    
    override var preferredContentSize: CGSize {
        willSet {
            guard newValue.height >= ScreenSize.minReasonableKeyboardHeight else {
                return
            }
            customInputContainerHeightConstraint.constant = newValue.height - inputBarView.frame.height
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardManager.delegate = self
        inputTextView.delegate = self
        minimizeHeight()
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        minimizeHeight()
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        if (container as? UIViewController) == audioViewController {
            audioInputContainerWidthConstraint.constant = container.preferredContentSize.width
            UIView.animate(withDuration: 0.3) {
                self.inputBarView.layoutIfNeeded()
            }
        }
    }
    
    func finishLoading() {
        audioViewController.loadViewIfNeeded()
        addChild(audioViewController)
        audioInputContainerView.addSubview(audioViewController.view)
        audioViewController.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        audioViewController.didMove(toParent: self)
        
        stickersViewController.loadViewIfNeeded()
        stickersViewController.reload()
        
        extensionViewController.loadViewIfNeeded()
        DispatchQueue.global().async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let dataSource = weakSelf.dataSource
            let ownerUser = dataSource.ownerUser
            var ownerUserApp: App?
            if dataSource.category == .group {
                let apps = AppDAO.shared.getConversationBots(conversationId: dataSource.conversationId)
                weakSelf.extensionViewController.apps = apps
            } else if let ownerId = ownerUser?.userId, let app = AppDAO.shared.getApp(ofUserId: ownerId) {
                ownerUserApp = app
            }
            DispatchQueue.main.sync {
                if dataSource.category == .contact, let ownerUser = ownerUser, !ownerUser.isBot {
                    weakSelf.extensionViewController.fixedExtensions = [.transfer, .call, .camera, .file, .contact]
                } else if let app = ownerUserApp, app.creatorId == AccountAPI.shared.accountUserId {
                    weakSelf.extensionViewController.fixedExtensions = [.transfer, .camera, .file, .contact]
                } else {
                    weakSelf.extensionViewController.fixedExtensions = [.camera, .file, .contact]
                }
            }
        }
    }
    
    func resignInputTextViewFirstResponder() {
        guard inputTextView.isFirstResponder else {
            return
        }
        keyboardManager.inputAccessoryViewHeight = 0
        inputTextView.resignFirstResponder()
    }
    
    func update(opponentUser: UserItem?) {
        if let user = opponentUser {
            let isBlocked = user.relationship == Relationship.BLOCKING.rawValue
            unblockButton.isHidden = !isBlocked
            appButton.isHidden = !user.isBot
        } else {
            
        }
    }
    
    @IBAction func extensionToggleAction(_ sender: ConversationExtensionSwitch) {
        resignTextViewFirstResponderWithoutNotifyingContentHeightChange()
        if sender.isOn {
            photosButton.isSelected = false
            loadCustomInputViewController(extensionViewController)
            setRightAccessoryButton(stickersButton)
        } else {
            removeCurrentCustomInputViewController {
                self.minimizeHeight()
            }
        }
    }
    
    @IBAction func showStickersAction(_ sender: Any) {
        resignTextViewFirstResponderWithoutNotifyingContentHeightChange()
        loadCustomInputViewController(stickersViewController)
        setRightAccessoryButton(keyboardButton)
        extensionsSwitch.isOn = false
    }
    
    @IBAction func showKeyboardAction(_ sender: Any) {
        removeCurrentCustomInputViewController(animationAlongside: nil)
        inputTextView.becomeFirstResponder()
        setRightAccessoryButton(stickersButton)
    }
    
    @IBAction func showPhotosAction(_ sender: Any) {
        resignTextViewFirstResponderWithoutNotifyingContentHeightChange()
        photosButton.isSelected.toggle()
        if photosButton.isSelected {
            loadCustomInputViewController(photoViewController)
        } else {
            removeCurrentCustomInputViewController {
                self.minimizeHeight()
            }
        }
    }
    
    private func increaseHeightIfNeeded() {
        guard view.frame.height < ScreenSize.minReasonableKeyboardHeight else {
            return
        }
        preferredContentSize.height = ScreenSize.defaultKeyboardHeight + inputBarView.frame.height
    }
    
    private func minimizeHeight() {
        let height = inputBarView.frame.height
            + view.compatibleSafeAreaInsets.bottom
        preferredContentSize.height = height
    }
    
    private func resignTextViewFirstResponderWithoutNotifyingContentHeightChange() {
        guard inputTextView.isFirstResponder else {
            return
        }
        reportHeightChangeWhenKeyboardFrameChanges = false
        inputTextView.resignFirstResponder()
        reportHeightChangeWhenKeyboardFrameChanges = true
    }
    
    private func loadCustomInputViewController(_ viewController: UIViewController) {
        customInputContainerView.alpha = 0
        customInputViewController = viewController
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.customInputContainerView.alpha = 1
            self.increaseHeightIfNeeded()
        }
    }
    
    private func removeCurrentCustomInputViewController(animationAlongside animation: (() -> Void)?) {
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.customInputContainerView.alpha = 0
            animation?()
        }) { (_) in
            self.customInputViewController = nil
        }
    }
    
    // The param of button should be either keyboardButton or stickersButton
    private func setRightAccessoryButton(_ button: UIButton) {
        guard button.alpha == 0 else {
            return
        }
        
        func switchButton(from: UIButton, to: UIButton) {
            let t = CGAffineTransform(scaleX: 0.6, y: 0.6)
            to.transform = t
            to.alpha = 0
            let duration = 0.2
            let options: UIView.AnimationOptions = [
                .overrideInheritedDuration,
                .overrideInheritedOptions,
                .overrideInheritedCurve
            ]
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                from.alpha = 0
                to.alpha = 1
            }, completion: nil)
            UIView.animate(withDuration: duration / 2, delay: 0, options: options, animations: {
                from.transform = t
            }, completion: nil)
            UIView.animate(withDuration: duration / 2, delay: duration / 2, options: options, animations: {
                to.transform = .identity
            }) { (_) in
                from.transform = .identity
            }
        }
        
        if button == stickersButton {
            switchButton(from: keyboardButton, to: stickersButton)
        } else {
            switchButton(from: stickersButton, to: keyboardButton)
        }
    }
    
}

extension ConversationInputViewController: ConversationKeyboardManagerDelegate {
    
    func conversationKeyboardManagerScrollViewForInteractiveKeyboardDismissing(_ manager: ConversationKeyboardManager) -> UIScrollView {
        return conversationViewController.tableView
    }
    
    func conversationKeyboardManager(_ manager: ConversationKeyboardManager, keyboardWillChangeFrameTo newFrame: CGRect, intent: ConversationKeyboardManager.KeyboardIntent) {
        var height = inputBarView.frame.height
        if intent == .hide {
            height += view.compatibleSafeAreaInsets.bottom
            UIView.performWithoutAnimation {
                view.backgroundColor = .white
            }
        } else if intent == .show {
            height += AppDelegate.current.window!.frame.height - newFrame.origin.y
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.view.backgroundColor = .clear
            }
        }
        if reportHeightChangeWhenKeyboardFrameChanges {
            preferredContentSize.height = height
        }
    }
    
}

extension ConversationInputViewController: UITextViewDelegate {
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        extensionsSwitch.isOn = false
        photosButton.isSelected = false
        setRightAccessoryButton(stickersButton)
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView.text.isNilOrEmpty {
            beginEditingInputTextViewTrailingConstraint.priority = .defaultLow
            beginEditingRightActionsStackLeadingConstraint.priority = .defaultLow
            endEditingInputTextViewTrailingConstraint.priority = .defaultHigh
            endEditingRightActionsStackTrailingConstraint.priority = .defaultHigh
            UIView.animate(withDuration: 0.3) {
                self.inputBarView.layoutIfNeeded()
                self.sendButton.alpha = 0
                self.rightActionsStackView.alpha = 1
                self.audioInputContainerView.alpha = 1
            }
        } else {
            beginEditingInputTextViewTrailingConstraint.priority = .defaultHigh
            beginEditingRightActionsStackLeadingConstraint.priority = .defaultHigh
            endEditingInputTextViewTrailingConstraint.priority = .defaultLow
            endEditingRightActionsStackTrailingConstraint.priority = .defaultLow
            UIView.animate(withDuration: 0.3) {
                self.inputBarView.layoutIfNeeded()
                self.sendButton.alpha = 1
                self.rightActionsStackView.alpha = 0
                self.audioInputContainerView.alpha = 0
            }
        }
    }
    
}
