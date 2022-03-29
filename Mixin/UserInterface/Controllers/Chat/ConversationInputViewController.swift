import UIKit
import Photos
import MixinServices

protocol ConversationInputInteractiveResizableViewController {
    var interactiveResizableScrollView: UIScrollView { get }
}

class ConversationInputViewController: UIViewController {
    
    typealias Quote = (message: MessageItem, thumbnail: UIImage?)
    
    @IBOutlet weak var quotePreviewView: QuotePreviewView!
    @IBOutlet weak var deleteConversationButton: BusyButton!
    @IBOutlet weak var unblockButton: BusyButton!
    @IBOutlet weak var inputBarView: UIView!
    @IBOutlet weak var extensionsSwitch: ConversationExtensionSwitch!
    @IBOutlet weak var textView: ConversationInputTextView!
    @IBOutlet weak var textViewRightAccessoryView: UIView!
    @IBOutlet weak var stickersButton: UIButton!
    @IBOutlet weak var keyboardButton: UIButton!
    @IBOutlet weak var appButton: UIButton!
    @IBOutlet weak var rightActionsStackView: UIStackView!
    @IBOutlet weak var photosButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var audioInputContainerView: UIView!
    @IBOutlet weak var customInputContainerView: UIView!
    
    @IBOutlet weak var quotePreviewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var quotePreviewWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewRightAccessoryWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var beginEditingTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var beginEditingRightActionsStackLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingRightActionsStackTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var audioInputContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var customInputContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var customInputContainerMinHeightConstraint: NSLayoutConstraint!
    
    lazy var extensionViewController = R.storyboard.chat.extension()!
    lazy var stickersViewController = R.storyboard.chat.stickerInput()!
    lazy var photoViewController = R.storyboard.chat.photoInput()!
    lazy var audioViewController = R.storyboard.chat.audioInput()!
    
    var detectsMentionToken = false
    
    var minimizedHeight: CGFloat {
        return quotePreviewWrapperHeightConstraint.constant
            + inputBarView.frame.height
            + view.safeAreaInsets.bottom
    }
    
    var regularHeight: CGFloat {
        return quotePreviewWrapperHeightConstraint.constant
            + inputBarView.frame.height
            + customInputHeight
    }
    
    var maximizedHeight: CGFloat {
        return UIView.layoutFittingExpandedSize.height
    }
    
    var quote: Quote? {
        didSet {
            updateQuotePreview(oldValue: oldValue)
        }
    }
    
    var isMaximizable: Bool {
        return customInputViewController is ConversationInputInteractiveResizableViewController
    }
    
    private let interactiveDismissResponder = InteractiveDismissResponder(height: 50)
    private let maxInputRow: Int = {
        if ScreenHeight.current <= .short {
            return 4
        } else {
            return 5
        }
    }()
    
    private var mentionRanges = Set<NSRange>()
    private var typingAttributes: [NSAttributedString.Key: Any] = [:]
    private var lastSelectedRange: NSRange!
    private var lastTextCountWhenMentionRangeChanges = 0
    private var lastSafeAreaInsetsBottom: CGFloat = 0
    private var reportHeightChangeWhenKeyboardFrameChanges = true
    private var lastMentionDetectedText: String?
    private var makeTextViewFirstResponderOnSilentMessagePreviewClose = false
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
    
    // UIViewController's preferredContentSizeDidChange is not fired for same values being set again
    // Also we need more precisive controlling for animations so we declare a custom one
    // Do not set this var directly, use setPreferredContentHeight:animated:
    private var preferredContentHeight: CGFloat = 0
    
    // By changing selection inside textViewDidChangeSelection
    // [textView selectedRange:] triggers another delegate call immediately
    // Resolve the recursion with this flag
    private var isManipulatingSelection = false
    
    private weak var silentNotificationMessagePreviewIfLoaded: SilentNotificationMessagePreviewViewController?
    
    private var conversationViewController: ConversationViewController {
        return parent as! ConversationViewController
    }
    
    var composer: ConversationMessageComposer {
        return conversationViewController.composer
    }
    
    private var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    private var height: Height {
        if abs(preferredContentHeight - maximizedHeight) < 1 {
            return .maximized
        } else if abs(preferredContentHeight - minimizedHeight) < 1 {
            return .minimized
        } else {
            return .regular
        }
    }
    
    private var trimmedMessageDraft: String {
        return textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var customInputHeight: CGFloat {
        let lastKeyboardHeightIsAvailable = KeyboardHeight.last <= KeyboardHeight.maxReasonable
            && KeyboardHeight.last >= KeyboardHeight.minReasonable
        return lastKeyboardHeightIsAvailable ? KeyboardHeight.last : KeyboardHeight.default
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        lastSelectedRange = textView.selectedRange
        lastTextCountWhenMentionRangeChanges = textView.text.count
        typingAttributes[.font] = textView.font
        typingAttributes[.foregroundColor] = textView.textColor
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveDraft), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: ParticipantDAO.participantDidChangeNotification, object: nil)
        textView.textContainer.lineFragmentPadding = 0
        textView.inputAccessoryView = interactiveDismissResponder
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.placeholderLabel.font = .systemFont(ofSize: 13)
        textView.placeholderLabel.adjustsFontSizeToFitWidth = true
        textView.placeholderPadding = UIEdgeInsets(top: textView.textContainerInset.top,
                                                   left: textView.textContainerInset.left,
                                                   bottom: textView.textContainerInset.bottom,
                                                   right: textViewRightAccessoryWidthConstraint.constant)
        textView.delegate = self
        let recognizer = PreviewGestureRecognizer(target: self, action: #selector(previewSilentNotificationMessage(_:)))
        sendButton.addGestureRecognizer(recognizer)
        lastSafeAreaInsetsBottom = view.safeAreaInsets.bottom
        setPreferredContentHeight(minimizedHeight, animated: false)
        if let draft = AppGroupUserDefaults.User.conversationDraft[composer.conversationId], !draft.isEmpty {
            UIView.performWithoutAnimation {
                layoutForTextViewIsEmpty(false, animated: false)
                textView.text = draft
                textViewDidChange(textView)
                textView.contentOffset.y = textView.contentSize.height - textView.frame.height
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reportHeightChangeWhenKeyboardFrameChanges = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reportHeightChangeWhenKeyboardFrameChanges = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveDraft()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard UIApplication.shared.isPortrait else {
            return
        }
        let diff = view.safeAreaInsets.bottom - lastSafeAreaInsetsBottom
        lastSafeAreaInsetsBottom = view.safeAreaInsets.bottom
        if abs(diff) > 1 {
            // This function call triggers recursion on iOS 12.0
            // It's fine to breaking out on the UIKit's own but for the correct height value
            // ALWAYS call it after lastSafeAreaInsetsBottom is set
            setPreferredContentHeight(preferredContentHeight + diff, animated: false)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if height != .minimized {
            customInputContainerHeightConstraint.constant = view.frame.height
                - quotePreviewWrapperHeightConstraint.constant
                - inputBarView.frame.height
        }
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        if (container as? UIViewController) == audioViewController {
            let isExpanding = container.preferredContentSize.width > audioInputContainerWidthConstraint.constant
            audioInputContainerWidthConstraint.constant = container.preferredContentSize.width
            if isExpanding {
                UIView.animate(withDuration: 0.3) {
                    self.inputBarView.layoutIfNeeded()
                }
            } else {
                inputBarView.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func unblockAction(_ sender: Any) {
        guard let user = composer.ownerUser else {
            return
        }
        unblockButton.isBusy = true
        UserAPI.unblockUser(userId: user.userId) { (result) in
            switch result {
            case .success(let userResponse):
                UserDAO.shared.updateUsers(users: [userResponse], sendNotificationAfterFinished: true)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @IBAction func deleteConversationAction(_ sender: Any) {
        guard !composer.conversationId.isEmpty else {
            return
        }
        deleteConversationButton.isBusy = true
        let conversationId = composer.conversationId

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: { (_) in
            self.deleteConversationButton.isBusy = false
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.group_menu_delete(), style: .destructive, handler: { (_) in
            DispatchQueue.global().async { [weak self] in
                ConversationDAO.shared.deleteChat(conversationId: conversationId)
                DispatchQueue.main.async {
                    self?.navigationController?.backToHome()
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func toggleExtensionAction(_ sender: ConversationExtensionSwitch) {
        if sender.isOn {
            resignTextViewFirstResponderWithoutReportingContentHeightChange()
            if height == .maximized {
                setPreferredContentHeightAnimated(.regular)
            }
            setPhotosButtonSelected(false)
            setRightAccessoryButton(stickersButton)
            loadCustomInputViewController(extensionViewController)
        } else {
            textView.becomeFirstResponder()
        }
    }
    
    @IBAction func showStickersAction(_ sender: Any) {
        quote = nil
        resignTextViewFirstResponderWithoutReportingContentHeightChange()
        setRightAccessoryButton(keyboardButton)
        extensionsSwitch.isOn = false
        setPhotosButtonSelected(false)
        loadCustomInputViewController(stickersViewController)
    }
    
    @IBAction func showKeyboardAction(_ sender: Any) {
        dismissCustomInput(minimize: false)
        textView.becomeFirstResponder()
        setRightAccessoryButton(stickersButton)
    }
    
    // TODO: use view controller based web view and present it right here
    @IBAction func openOpponentAppAction(_ sender: Any) {
        guard let app = composer.opponentApp else {
            return
        }
        dismiss()
        conversationViewController.openOpponentApp(app)
    }
    
    @IBAction func showPhotosAction(_ sender: Any) {
        let status: PHAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            status = PHPhotoLibrary.authorizationStatus()
        }
        handlePhotoAuthorizationStatus(status)
    }
    
    @IBAction func sendTextMessageAction(_ sender: Any) {
        sendTextMessage(silentNotification: false)
    }
    
    // MARK: - Interface
    func finishLoading() {
        customInputContainerMinHeightConstraint.constant = customInputHeight
        
        addChild(audioViewController)
        audioInputContainerView.addSubview(audioViewController.view)
        audioViewController.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        audioViewController.didMove(toParent: self)
        
        stickersViewController.loadViewIfNeeded()
        stickersViewController.reload()
        
        extensionViewController.loadViewIfNeeded()
        if composer.isGroup {
            let conversationId = composer.conversationId
            composer.queue.async {
                let apps = AppDAO.shared.getConversationBots(conversationId: conversationId)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.extensionViewController.apps = apps.map { ($0, nil) }
                    self.reloadFixedExtensions()
                    self.textView.placeholder = R.string.localizable.e2e_encrypted()
                }
            }
        } else if let ownerUser = composer.ownerUser {
            composer.loadOpponentApp(userId: ownerUser.userId) { [weak self] app in
                guard let self = self else {
                    return
                }
                let isEncrypted: Bool
                if let app = app {
                    AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
                    isEncrypted = app.capabilities?.contains("ENCRYPTED") ?? false
                } else {
                    isEncrypted = true
                }
                self.loadFavoriteApps(ownerUser: ownerUser)
                self.reloadFixedExtensions()
                self.textView.placeholder = isEncrypted ? R.string.localizable.e2e_encrypted() : nil
            }
        }
        
        quotePreviewView.dismissAction = { [weak self] in
            self?.quote = nil
        }
        
        let recognizer = InteractiveResizeGestureRecognizer(target: self, action: #selector(interactiveResizeAction(_:)))
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
    }
    
    func update(opponentUser user: UserItem) {
        let isBlocked = user.relationship == Relationship.BLOCKING.rawValue
        unblockButton.isHidden = !isBlocked
        if !isBlocked && unblockButton.isBusy {
            unblockButton.isBusy = false
        }
        appButton.isHidden = !user.isBot
        composer.loadOpponentApp(userId: user.userId, completion: nil)
    }
    
    func dismissCustomInput(minimize: Bool) {
        setRightAccessoryButton(stickersButton)
        setPhotosButtonSelected(false)
        extensionsSwitch.isOn = false
        if minimize {
            setPreferredContentHeightAnimated(.minimized)
        }
        photoViewController.dismissMediasPreviewControllerIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            self.customInputContainerView.alpha = 0
        } completion: { _ in
            self.customInputViewController = nil
        }
    }
    
    func setPreferredContentHeightAnimated(_ height: Height) {
        let heightValue: CGFloat
        switch height {
        case .minimized:
            heightValue = minimizedHeight
        case .regular:
            heightValue = regularHeight
        case .maximized:
            heightValue = maximizedHeight
        }
        setPreferredContentHeight(heightValue, animated: true)
    }
    
    func dismiss() {
        if textView.isFirstResponder {
            textView.resignFirstResponder()
        } else if height != .minimized {
            dismissCustomInput(minimize: true)
        }
    }
    
    func send(asset: PHAsset) {
        composer.send(asset: asset, quoteMessageId: quote?.message.messageId)
        quote = nil
    }
    
    func send(image: UIImage) {
        composer.send(image: image, quoteMessageId: quote?.message.messageId)
        quote = nil
    }
    
    func sendAudio(url: URL, metadata: AudioMetadata) {
        composer.sendMessage(type: .SIGNAL_AUDIO, quote: quote?.message, value: (url, metadata))
        quote = nil
    }
    
    func sendFile(url: URL) {
        composer.sendMessage(type: .SIGNAL_DATA, quote: quote?.message, value: url)
        quote = nil
    }
    
    func moveAndSendVideo(at source: URL) {
        composer.moveAndSendVideo(at: source, quoteMessageId: quote?.message.messageId)
        quote = nil
    }
    
    func moveAndSendGifImage(at source: URL, image: UIImage) {
        composer.moveAndSendGifImage(at: source, image: image, quoteMessageId: quote?.message.messageId)
        quote = nil
    }
    
    func sendContact(userIds: [String], completion: @escaping () -> Void) {
        let conversationId = composer.conversationId
        let ownerUser = composer.ownerUser
        let app = composer.opponentApp
        let isGroup = composer.isGroup
        var quoteMessageId = quote?.message.messageId
        quote = nil
        DispatchQueue.global().async {
            for userId in userIds {
                var message = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue,
                                                    conversationId: conversationId,
                                                    userId: myUserId)
                message.sharedUserId = userId
                if let id = quoteMessageId {
                    // Apply quoted message to first message only
                    message.quoteMessageId = id
                    quoteMessageId = nil
                }
                let transferData = TransferContactData(userId: userId)
                message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
                SendMessageService.shared.sendMessage(message: message,
                                                      ownerUser: ownerUser,
                                                      opponentApp: app,
                                                      isGroupMessage: isGroup)
            }
            DispatchQueue.main.async(execute: completion)
        }
    }
    
    func send(location: Location) throws {
        let quoteMessageId = quote?.message.messageId
        quote = nil
        var message = Message.createMessage(category: MessageCategory.SIGNAL_LOCATION.rawValue,
                                            conversationId: composer.conversationId,
                                            userId: myUserId)
        let jsonData = try JSONEncoder().encode(location)
        message.content = String(data: jsonData, encoding: .utf8)
        message.quoteMessageId = quoteMessageId
        SendMessageService.shared.sendMessage(message: message,
                                              ownerUser: composer.ownerUser,
                                              opponentApp: composer.opponentApp,
                                              isGroupMessage: composer.isGroup)
    }
    
}

// MARK: - Callbacks
extension ConversationInputViewController {
    
    @objc private func keyboardDidShow(_ notification: Notification) {
        guard textView.isFirstResponder else {
            return
        }
        view.backgroundColor = .clear
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardWillBeInvisible = (screenHeight - endFrame.origin.y) <= 1
        guard textView.isFirstResponder || (keyboardWillBeInvisible && customInputViewController == nil) || (presentedViewController?.isBeingDismissed ?? false) else {
            return
        }
        if !keyboardWillBeInvisible {
            KeyboardHeight.last = endFrame.height - interactiveDismissResponder.height
            customInputContainerMinHeightConstraint.constant = customInputHeight
        }
        guard reportHeightChangeWhenKeyboardFrameChanges else {
            return
        }
        if keyboardWillBeInvisible {
            setPreferredContentHeight(minimizedHeight, animated: true)
        } else {
            var height = quotePreviewWrapperHeightConstraint.constant
                + inputBarView.frame.height
                + screenHeight
                - endFrame.origin.y
                - interactiveDismissResponder.height
            height = max(minimizedHeight, height)
            if view.frame.height != height {
                setPreferredContentHeight(height, animated: true)
            }
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.performWithoutAnimation {
            self.view.backgroundColor = .background
        }
    }
    
    @objc private func saveDraft() {
        guard parent != nil else {
            return
        }
        AppGroupUserDefaults.User.conversationDraft[composer.conversationId] = trimmedMessageDraft
    }
    
    @objc private func participantDidChange(_ notification: Notification) {
        guard parent != nil else {
            return
        }
        guard let conversationId = notification.userInfo?[ParticipantDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard composer.isGroup, composer.conversationId == conversationId else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            let apps = AppDAO.shared.getConversationBots(conversationId: conversationId)
            DispatchQueue.main.sync {
                self?.extensionViewController.apps = apps.map { ($0, nil) }
            }
        }
    }
    
    @objc private func interactiveResizeAction(_ recognizer: InteractiveResizeGestureRecognizer) {
        let location = recognizer.location(in: view)
        let verticalVelocity = recognizer.velocity(in: view).y
        let resizableScrollView = (customInputViewController as? ConversationInputInteractiveResizableViewController)?.interactiveResizableScrollView
        switch recognizer.state {
        case .began:
            recognizer.beganInInputBar = inputBarView.frame.contains(location)
            let downsizeByDraggingOnScrollView = view.frame.height > regularHeight
                && verticalVelocity > 0
                && (resizableScrollView != nil)
                && (resizableScrollView!.contentOffset.y < 1)
                && resizableScrollView!.bounds.contains(recognizer.location(in: resizableScrollView))
            if recognizer.beganInInputBar || downsizeByDraggingOnScrollView {
                recognizer.shouldAdjustContentHeight = true
            }
            recognizer.canSizeToMinimized = view.frame.height <= regularHeight
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            if !recognizer.shouldAdjustContentHeight {
                let canUpsize = preferredContentHeight < maximizedHeight
                    && inputBarView.frame.contains(location)
                if canUpsize {
                    recognizer.shouldAdjustContentHeight = true
                }
            }
            if recognizer.shouldAdjustContentHeight {
                var translation = recognizer.translation(in: view).y
                if !recognizer.beganInInputBar, let scrollView = resizableScrollView {
                    scrollView.contentOffset.y += translation
                }
                if !recognizer.canSizeToMinimized && (view.frame.height - translation) < regularHeight {
                    translation /= 2
                }
                let height = view.frame.height - translation
                setPreferredContentHeight(height, animated: false)
            }
            recognizer.setTranslation(.zero, in: view)
        case .ended:
            if recognizer.shouldAdjustContentHeight {
                if verticalVelocity > 50 {
                    if view.frame.height < regularHeight && recognizer.canSizeToMinimized {
                        dismissCustomInput(minimize: true)
                    } else {
                        setPreferredContentHeightAnimated(.regular)
                    }
                } else {
                    if view.frame.height > regularHeight {
                        setPreferredContentHeightAnimated(.maximized)
                    } else {
                        setPreferredContentHeightAnimated(.regular)
                    }
                }
            }
        default:
            break
        }
    }
    
    @objc private func previewSilentNotificationMessage(_ recognizer: UIGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let preview = SilentNotificationMessagePreviewViewController()
            preview.delegate = self
            preview.show(in: conversationViewController, textView: textView, sendButton: sendButton)
            silentNotificationMessagePreviewIfLoaded = preview
        case .changed, .ended:
            silentNotificationMessagePreviewIfLoaded?.handleGestureChange(with: recognizer)
        default:
            break
        }
    }
    
    @objc private func sendTextMessageSilently() {
        sendTextMessage(silentNotification: true)
    }
    
}

// MARK: - Embedded class
extension ConversationInputViewController {
    
    enum Height {
        case minimized
        case regular
        case maximized
    }
    
    private class InteractiveResizeGestureRecognizer: UIPanGestureRecognizer {
        
        var beganInInputBar = false
        var shouldAdjustContentHeight = false
        var canSizeToMinimized = false
        
        override func reset() {
            super.reset()
            shouldAdjustContentHeight = false
            canSizeToMinimized = false
        }
        
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension ConversationInputViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return isMaximizable
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer is UIScreenEdgePanGestureRecognizer
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Avoid conflicting with audio recording
        return !(otherGestureRecognizer is UILongPressGestureRecognizer)
    }
    
}

// MARK: - UITextViewDelegate
extension ConversationInputViewController: UITextViewDelegate {
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        dismissCustomInput(minimize: false)
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        view.backgroundColor = .background
        return true
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textView.typingAttributes = typingAttributes
        if !text.isEmpty {
            textView.textStorage.addAttributes(typingAttributes, range: range)
        }
        return !audioViewController.isRecording
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let fullRange = NSRange(location: 0, length: textView.attributedText.length)
        var rangesToRemove = [NSRange]()
        mentionRanges.removeAll()
        textView.attributedText.enumerateAttribute(.mentionToken, in: fullRange, options: [], using: { (value, range, stop) in
            guard let length = (value as? MentionToken)?.length else {
                return
            }
            if length == range.length {
                mentionRanges.insert(range)
            } else {
                rangesToRemove.append(range)
            }
        })
        
        if !rangesToRemove.isEmpty {
            DispatchQueue.main.async {
                for range in rangesToRemove.reversed() {
                    let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
                    mutable.replaceCharacters(in: range, with: "")
                    textView.attributedText = NSAttributedString(attributedString: mutable)
                    textView.selectedRange = NSRange(location: range.location, length: 0)
                }
                self.textViewDidChange(textView)
            }
            return
        }
        
        lastTextCountWhenMentionRangeChanges = textView.text.count
        
        guard let lineHeight = textView.font?.lineHeight else {
            return
        }
        if sendButton.alpha == 0 && !textView.text.isEmpty {
            layoutForTextViewIsEmpty(false, animated: true)
        } else if sendButton.alpha == 1 && textView.text.isEmpty {
            layoutForTextViewIsEmpty(true, animated: true)
        }
        let maxHeight = ceil(lineHeight * CGFloat(maxInputRow)
            + textView.textContainerInset.top
            + textView.textContainerInset.bottom)
        let sizeToFit = CGSize(width: textView.bounds.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let contentHeight = ceil(textView.sizeThatFits(sizeToFit).height)
        textView.isScrollEnabled = contentHeight > maxHeight
        let newHeight = min(contentHeight, maxHeight)
        let diff = newHeight - textViewHeightConstraint.constant
        if abs(diff) > 0.1 {
            textViewHeightConstraint.constant = newHeight
            setPreferredContentHeight(preferredContentHeight + diff, animated: true)
            interactiveDismissResponder.height += diff
        }
        
        detectAndReportMentionCandidateIfNeeded()
        lastMentionDetectedText = textView.text
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard textView == self.textView else {
            return
        }
        guard !isManipulatingSelection else {
            return
        }
        isManipulatingSelection = true
        defer {
            isManipulatingSelection = false
        }
        
        var selectedRange = textView.selectedRange
        if selectedRange.length == 0 {
            let mentionRangeWithCaretInside = mentionRanges.first { (range) -> Bool in
                selectedRange.location > range.location && selectedRange.location < NSMaxRange(range)
            }
            if textView.text.count == lastTextCountWhenMentionRangeChanges, let range = mentionRangeWithCaretInside {
                let isCursorGoingBackward: Bool
                if self.textView.isFloatingCursor {
                    isCursorGoingBackward = self.textView.isFloatingCursorGoingBackward
                } else {
                    isCursorGoingBackward = selectedRange.location < lastSelectedRange.location
                }
                let isCursorGoingForward: Bool
                if self.textView.isFloatingCursor {
                    isCursorGoingForward = self.textView.isFloatingCursorGoingForward
                } else {
                    isCursorGoingForward = selectedRange.location > lastSelectedRange.location
                }
                if isCursorGoingBackward {
                    textView.selectedRange = NSRange(location: range.location, length: 0)
                } else if isCursorGoingForward {
                    textView.selectedRange = NSRange(location: NSMaxRange(range), length: 0)
                }
            }
        } else {
            for mentionRange in mentionRanges {
                if mentionRange.intersection(selectedRange) != nil {
                    selectedRange.formUnion(mentionRange)
                }
            }
            textView.selectedRange = selectedRange
        }
        lastSelectedRange = textView.selectedRange
        textView.typingAttributes = typingAttributes
        
        if textView.text == lastMentionDetectedText {
            // Only detects on cursor movement
            // Ignore any selection change caused by text input
            detectAndReportMentionCandidateIfNeeded()
        }
    }
    
}

// MARK: - SilentNotificationMessagePreviewViewControllerDelegate
extension ConversationInputViewController: SilentNotificationMessagePreviewViewControllerDelegate {
    
    func silentNotificationMessagePreviewViewControllerWillShow(_ viewController: SilentNotificationMessagePreviewViewController) {
        textView.textColor = .clear
        sendButton.isHidden = true
        if textView.isFirstResponder {
            makeTextViewFirstResponderOnSilentMessagePreviewClose = true
            resignTextViewFirstResponderWithoutReportingContentHeightChange()
        }
    }
    
    func silentNotificationMessagePreviewViewController(_ viewController: SilentNotificationMessagePreviewViewController, didSelectSendWithNotification notify: Bool) {
        viewController.dismiss(hideSendNormallyButton: true) {
            self.sendTextMessage(silentNotification: !notify)
        }
    }
    
    func silentNotificationMessagePreviewViewControllerDidClose(_ viewController: SilentNotificationMessagePreviewViewController) {
        textView.textColor = typingAttributes[.foregroundColor] as? UIColor
        sendButton.isHidden = false
        if makeTextViewFirstResponderOnSilentMessagePreviewClose {
            textView.becomeFirstResponder()
            makeTextViewFirstResponderOnSilentMessagePreviewClose = false
        }
        silentNotificationMessagePreviewIfLoaded = nil
    }
    
}

// MARK: - Private works
extension ConversationInputViewController {
    
    private class PreviewGestureRecognizer: UILongPressGestureRecognizer {
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            if state == .possible, let touch = touches.first, touch.force / touch.maximumPossibleForce > 0.7 {
                state = .began
            }
        }
        
    }
    
    private func setPhotosButtonSelected(_ selected: Bool) {
        photosButton.isSelected = selected
        photosButton.tintColor = selected ? R.color.theme() : R.color.icon_tint()
    }
    
    private func setPreferredContentHeight(_ height: CGFloat, animated: Bool) {
        preferredContentHeight = height
        conversationViewController.updateInputWrapper(for: height, animated: animated)
    }
    
    private func resignTextViewFirstResponderWithoutReportingContentHeightChange() {
        guard textView.isFirstResponder else {
            return
        }
        reportHeightChangeWhenKeyboardFrameChanges = false
        textView.resignFirstResponder()
        reportHeightChangeWhenKeyboardFrameChanges = true
    }
    
    private func reloadFixedExtensions() {
        if !composer.isGroup, let ownerUser = composer.ownerUser, !ownerUser.isBot {
            extensionViewController.fixedExtensions = [.transfer, .call, .camera, .file, .contact, .location]
        } else if let app = composer.opponentApp, app.creatorId == myUserId {
            extensionViewController.fixedExtensions = [.transfer, .camera, .file, .contact, .location]
        } else if composer.isGroup {
            extensionViewController.fixedExtensions = [.camera, .groupCall, .file, .contact, .location]
        } else {
            extensionViewController.fixedExtensions = [.camera, .file, .contact, .location]
        }
    }
    
    private func loadCustomInputViewController(_ viewController: UIViewController) {
        if view.frame.height < regularHeight {
            setPreferredContentHeightAnimated(.regular)
        }
        customInputContainerView.alpha = 0
        customInputViewController = viewController
        customInputContainerView.layoutIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            self.customInputContainerView.alpha = 1
        }
    }
    
    private func loadFavoriteApps(ownerUser: UserItem) {
        guard let account = LoginManager.shared.account else {
            return
        }
        
        let myUserItem = UserItem.createUser(from: account)
        let ownerId = ownerUser.userId
        
        func loadApps() {
            let myFavoriteApps = FavoriteAppsDAO.shared.favoriteAppsOfUser(withId: myUserId)
            let myFavoriteAppIds = Set(myFavoriteApps.map({ $0.appId }))
            let ownerFavoriteApps = FavoriteAppsDAO.shared.favoriteAppsOfUser(withId: ownerUser.userId)
                .filter({ !myFavoriteAppIds.contains($0.appId) })
            let apps: [(app: App, user: UserItem?)] = myFavoriteApps.map({ ($0, myUserItem) }) + ownerFavoriteApps.map({ ($0, ownerUser) })
            DispatchQueue.main.async { [weak self] in
                self?.extensionViewController.apps = apps
            }
        }
        
        DispatchQueue.global().async(execute: loadApps)
        UserAPI.getFavoriteApps(ofUserWith: ownerId) { (result) in
            guard case let .success(favApps) = result else {
                return
            }
            DispatchQueue.global().async {
                FavoriteAppsDAO.shared.updateFavoriteApps(favApps, forUserWith: ownerId)
                let appUserIds = favApps.map({ $0.appId })
                UserAPI.showUsers(userIds: appUserIds) { (result) in
                    guard case let .success(users) = result else {
                        return
                    }
                    UserDAO.shared.updateUsers(users: users)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: loadApps)
                }
            }
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
    
    private func layoutForTextViewIsEmpty(_ isEmpty: Bool, animated: Bool) {
        
        func layout() {
            if isEmpty {
                beginEditingTextViewTrailingConstraint.priority = .almostInexist
                beginEditingRightActionsStackLeadingConstraint.priority = .almostInexist
                endEditingTextViewTrailingConstraint.priority = .almostRequired
                endEditingRightActionsStackTrailingConstraint.priority = .almostRequired
                sendButton.alpha = 0
                rightActionsStackView.alpha = 1
                audioInputContainerView.alpha = 1
                textViewRightAccessoryView.alpha = 1
            } else {
                beginEditingTextViewTrailingConstraint.priority = .almostRequired
                beginEditingRightActionsStackLeadingConstraint.priority = .almostRequired
                endEditingTextViewTrailingConstraint.priority = .almostInexist
                endEditingRightActionsStackTrailingConstraint.priority = .almostInexist
                sendButton.alpha = 1
                rightActionsStackView.alpha = 0
                audioInputContainerView.alpha = 0
                textViewRightAccessoryView.alpha = 0
            }
            inputBarView.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: layout)
        } else {
            layout()
        }
    }
    
    private func updateQuotePreview(oldValue: Quote?) {
        let quotePreviewHeight = quotePreviewHeightConstraint.constant
        if let quote = quote {
            audioViewController.cancelIfRecording()
            UIView.performWithoutAnimation {
                quotePreviewView.render(message: quote.message, contentImageThumbnail: quote.thumbnail)
                quotePreviewView.layoutIfNeeded()
            }
            if oldValue == nil {
                quotePreviewView.alpha = 1
                quotePreviewWrapperHeightConstraint.constant = quotePreviewHeight
                interactiveDismissResponder.height += quotePreviewHeight
            }
            if textView.isFirstResponder || customInputViewController != nil {
                if oldValue == nil {
                    setPreferredContentHeight(preferredContentHeight + quotePreviewHeight, animated: true)
                }
            } else if customInputViewController == nil {
                textView.becomeFirstResponder()
            }
        } else if oldValue != nil {
            quotePreviewView.alpha = 0
            interactiveDismissResponder.height -= quotePreviewHeight
            let newHeight = preferredContentHeight - quotePreviewHeight
            quotePreviewWrapperHeightConstraint.constant = 0
            setPreferredContentHeight(newHeight, animated: true)
        }
    }
    
    private func loadPhotoInput() {
        resignTextViewFirstResponderWithoutReportingContentHeightChange()
        setPhotosButtonSelected(!photosButton.isSelected)
        extensionsSwitch.isOn = false
        setRightAccessoryButton(stickersButton)
        if photosButton.isSelected {
            loadCustomInputViewController(photoViewController)
        } else {
            dismissCustomInput(minimize: true)
        }
    }
    
    private func handlePhotoAuthorizationStatus(_ status: PHAuthorizationStatus) {
        switch status {
        case .limited:
            DispatchQueue.main.async {
                self.photoViewController.isAuthorizationLimited = true
                self.loadPhotoInput()
            }
        case .authorized:
            DispatchQueue.main.async {
                self.photoViewController.isAuthorizationLimited = false
                self.loadPhotoInput()
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(handlePhotoAuthorizationStatus)
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.alertSettings(R.string.localizable.permission_denied_photo_library())
            }
        @unknown default:
            DispatchQueue.main.async {
                self.alertSettings(R.string.localizable.permission_denied_photo_library())
            }
        }
    }
    
    private func detectAndReportMentionCandidateIfNeeded() {
        guard detectsMentionToken else {
            return
        }
        if let range = self.textView.inputingMentionTokenRange, !mentionRanges.contains(where: { $0.intersection(range) != nil }) {
            let keywordRange = NSRange(location: range.location + 1, length: range.length - 1)
            let text = (self.textView.text as NSString).substring(with: keywordRange)
            conversationViewController.inputTextViewDidInputMentionCandidate(text)
        } else {
            conversationViewController.inputTextViewDidInputMentionCandidate(nil)
        }
    }
    
    private func sendTextMessage(silentNotification: Bool) {
        textView.unmarkText()
        guard !trimmedMessageDraft.isEmpty else {
            return
        }
        composer.sendMessage(type: .SIGNAL_TEXT,
                             quote: quote?.message,
                             value: trimmedMessageDraft,
                             silentNotification: silentNotification)
        mentionRanges.removeAll()
        textView.text = ""
        textViewDidChange(textView)
        quote = nil
    }
    
}
