import UIKit
import Photos

protocol ConversationInputInteractiveResizableViewController {
    var interactiveResizableScrollView: UIScrollView { get }
}

class ConversationInputViewController: UIViewController {
    
    @IBOutlet weak var quotePreviewView: QuotePreviewView!
    @IBOutlet weak var deleteConversationButton: BusyButton!
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
    
    @IBOutlet weak var quotePreviewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var quotePreviewWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputTextViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var beginEditingInputTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var beginEditingRightActionsStackLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingInputTextViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var endEditingRightActionsStackTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var audioInputContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var customInputContainerHeightConstraint: NSLayoutConstraint!
    
    lazy var extensionViewController = R.storyboard.chat.extension()!
    lazy var stickersViewController = R.storyboard.chat.stickerInput()!
    lazy var photoViewController = R.storyboard.chat.photoInput()!
    lazy var audioViewController = R.storyboard.chat.audioInput()!
    
    var minimizedHeight: CGFloat {
        return quotePreviewWrapperHeightConstraint.constant
            + inputBarView.frame.height
            + view.compatibleSafeAreaInsets.bottom
    }
    
    var regularHeight: CGFloat {
        let keyboardHeight: CGFloat
        let lastKeyboardHeightIsAvailable = KeyboardHeight.last <= KeyboardHeight.maxReasonable
            && KeyboardHeight.last >= KeyboardHeight.minReasonable
        if lastKeyboardHeightIsAvailable {
            keyboardHeight = KeyboardHeight.last
        } else {
            keyboardHeight = KeyboardHeight.default
        }
        return quotePreviewWrapperHeightConstraint.constant
            + inputBarView.frame.height
            + keyboardHeight
    }
    
    var maximizedHeight: CGFloat {
        return UIView.layoutFittingExpandedSize.height
    }
    
    var quote: (message: MessageItem, thumbnail: UIImage?)? {
        didSet {
            updateQuotePreview()
        }
    }
    
    private let maxInputRow = 5
    private let interactiveDismissResponder = InteractiveDismissResponder(height: 50)
    
    private var lastSafeAreaInsetsBottom: CGFloat = 0
    private var reportHeightChangeWhenKeyboardFrameChanges = true
    private var opponentApp: App?
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
    
    private var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    private var size: Size {
        if abs(preferredContentSize.height - maximizedHeight) < 1 {
            return .maximized
        } else if abs(preferredContentSize.height - minimizedHeight) < 1 {
            return .minimized
        } else {
            return .regular
        }
    }
    
    private var trimmedMessageDraft: String {
        return inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveDraft), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        inputTextView.inputAccessoryView = interactiveDismissResponder
        inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        inputTextView.delegate = self
        lastSafeAreaInsetsBottom = view.compatibleSafeAreaInsets.bottom
        setPreferredContentHeight(minimizedHeight, animated: false)
        if let draft = CommonUserDefault.shared.getConversationDraft(dataSource.conversationId), !draft.isEmpty {
            UIView.performWithoutAnimation {
                layoutForInputTextViewIsEmpty(false, animated: false)
                inputTextView.text = draft
                textViewDidChange(inputTextView)
                inputTextView.contentOffset.y = inputTextView.contentSize.height - inputTextView.frame.height
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveDraft()
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let diff = view.compatibleSafeAreaInsets.bottom - lastSafeAreaInsetsBottom
        if abs(diff) > 1 {
            setPreferredContentHeight(preferredContentSize.height + diff, animated: false)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard size != .minimized else {
            return
        }
        customInputContainerHeightConstraint.constant = view.frame.height - inputBarView.frame.height
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
    
    // MARK: - Actions
    @IBAction func unblockAction(_ sender: Any) {
        guard let user = dataSource.ownerUser else {
            return
        }
        unblockButton.isBusy = true
        UserAPI.shared.unblockUser(userId: user.userId) { (result) in
            switch result {
            case .success(let userResponse):
                UserDAO.shared.updateUsers(users: [userResponse], sendNotificationAfterFinished: true)
            case .failure:
                break
            }
        }
    }
    
    @IBAction func deleteConversationAction(_ sender: Any) {
        guard !dataSource.conversationId.isEmpty else {
            return
        }
        deleteConversationButton.isBusy = true
        let conversationId = dataSource.conversationId
        DispatchQueue.global().async { [weak self] in
            ConversationDAO.shared.makeQuitConversation(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ConversationDidChange)
            DispatchQueue.main.async {
                self?.navigationController?.backToHome()
            }
        }
    }
    
    @IBAction func toggleExtensionAction(_ sender: ConversationExtensionSwitch) {
        resignTextViewFirstResponderWithoutReportingContentHeightChange()
        if sender.isOn {
            photosButton.isSelected = false
            setRightAccessoryButton(stickersButton)
            loadCustomInputViewController(extensionViewController)
        } else {
            dismissCustomInput(minimize: true)
        }
    }
    
    @IBAction func showStickersAction(_ sender: Any) {
        resignTextViewFirstResponderWithoutReportingContentHeightChange()
        setRightAccessoryButton(keyboardButton)
        extensionsSwitch.isOn = false
        photosButton.isSelected = false
        loadCustomInputViewController(stickersViewController)
    }
    
    @IBAction func showKeyboardAction(_ sender: Any) {
        dismissCustomInput(minimize: false)
        inputTextView.becomeFirstResponder()
        setRightAccessoryButton(stickersButton)
    }
    
    // TODO: use view controller based web view and present it right here
    @IBAction func openOpponentAppAction(_ sender: Any) {
        guard let user = dataSource.ownerUser, user.isBot, let app = opponentApp else {
            return
        }
        dismiss()
        conversationViewController.openOpponentApp(app)
    }
    
    @IBAction func showPhotosAction(_ sender: Any) {
        let status = PHPhotoLibrary.authorizationStatus()
        handlePhotoAuthorizationStatus(status)
    }
    
    @IBAction func sendTextMessageAction(_ sender: Any) {
        guard !trimmedMessageDraft.isEmpty else {
            return
        }
        dataSource.sendMessage(type: .SIGNAL_TEXT,
                               quoteMessageId: quote?.message.messageId,
                               value: trimmedMessageDraft)
        inputTextView.text = ""
        textViewDidChange(inputTextView)
        layoutForInputTextViewIsEmpty(true, animated: true)
        quote = nil
    }
    
    // MARK: - Interface
    func finishLoading() {
        addChild(audioViewController)
        audioInputContainerView.addSubview(audioViewController.view)
        audioViewController.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        audioViewController.didMove(toParent: self)
        
        stickersViewController.loadViewIfNeeded()
        stickersViewController.reload()
        
        extensionViewController.loadViewIfNeeded()
        if dataSource.category == .group {
            let apps = AppDAO.shared.getConversationBots(conversationId: dataSource.conversationId)
            extensionViewController.apps = apps
        } else if let ownerId = dataSource.ownerUser?.userId, let app = AppDAO.shared.getApp(ofUserId: ownerId) {
            opponentApp = app
        }
        if dataSource.category == .contact, let ownerUser = dataSource.ownerUser, !ownerUser.isBot {
            extensionViewController.fixedExtensions = [.transfer, .call, .camera, .file, .contact]
        } else if let app = opponentApp, app.creatorId == AccountAPI.shared.accountUserId {
            extensionViewController.fixedExtensions = [.transfer, .camera, .file, .contact]
        } else {
            extensionViewController.fixedExtensions = [.camera, .file, .contact]
        }
        
        quotePreviewView.dismissAction = { [weak self] in
            self?.quote = nil
        }
        
        let recognizer = InteractiveResizeGestureRecognizer(target: self, action: #selector(interactiveResizeAction(_:)))
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
    }
    
    func update(opponentUser: UserItem?) {
        guard let user = opponentUser else {
            return
        }
        let isBlocked = user.relationship == Relationship.BLOCKING.rawValue
        unblockButton.isHidden = !isBlocked
        if !isBlocked && unblockButton.isBusy {
            unblockButton.isBusy = false
        }
        appButton.isHidden = !user.isBot
    }
    
    func dismissCustomInput(minimize: Bool) {
        setRightAccessoryButton(stickersButton)
        photosButton.isSelected = false
        extensionsSwitch.isOn = false
        if minimize {
            setPreferredContentHeight(minimizedHeight, animated: true)
        }
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.customInputContainerView.alpha = 0
        }) { (_) in
            self.customInputViewController = nil
        }
    }
    
    func dismiss() {
        if inputTextView.isFirstResponder {
            inputTextView.resignFirstResponder()
        } else if size != .minimized {
            dismissCustomInput(minimize: true)
        }
    }
    
}

// MARK: - Callbacks
extension ConversationInputViewController {

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardWillBeInvisible = (screenHeight - endFrame.origin.y) <= 1
        if !keyboardWillBeInvisible {
            KeyboardHeight.last = endFrame.height - interactiveDismissResponder.height
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
            setPreferredContentHeight(height, animated: true)
        }
    }
    
    @objc private func saveDraft() {
        CommonUserDefault.shared.setConversationDraft(dataSource.conversationId, draft: trimmedMessageDraft)
    }
    
    @objc private func participantDidChange(_ notification: Notification) {
        guard dataSource.category == .group else {
            return
        }
        guard let conversationId = notification.object as? String, conversationId == dataSource.conversationId else {
            return
        }
        DispatchQueue.global().async {
            let apps = AppDAO.shared.getConversationBots(conversationId: self.dataSource.conversationId)
            DispatchQueue.main.sync {
                self.extensionViewController.apps = apps
            }
        }
    }
    
    @objc private func interactiveResizeAction(_ recognizer: InteractiveResizeGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.sizeWhenBegan = size
            let location = recognizer.location(in: view)
            recognizer.beganInInputBar = inputBarView.frame.contains(location)
            if recognizer.beganInInputBar {
                recognizer.shouldAdjustContentHeight = true
            }
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            let location = recognizer.location(in: view)
            if !recognizer.shouldAdjustContentHeight, inputBarView.frame.contains(location) {
                recognizer.shouldAdjustContentHeight = true
            }
            if recognizer.shouldAdjustContentHeight {
                if !recognizer.beganInInputBar, let scrollView = (customInputViewController as? ConversationInputInteractiveResizableViewController)?.interactiveResizableScrollView {
                    scrollView.contentOffset.y += recognizer.translation(in: view).y
                }
                let height = view.frame.height - recognizer.translation(in: view).y
                setPreferredContentHeight(height, animated: false)
            }
            recognizer.setTranslation(.zero, in: view)
        case .ended:
            if recognizer.shouldAdjustContentHeight {
                let verticalVelocity = recognizer.velocity(in: view).y
                if recognizer.sizeWhenBegan == .regular {
                    if verticalVelocity < 0 {
                        setPreferredContentHeight(maximizedHeight, animated: true)
                    } else if verticalVelocity > 0 && regularHeight - preferredContentSize.height > 60 {
                        dismissCustomInput(minimize: true)
                    } else {
                        setPreferredContentHeight(regularHeight, animated: true)
                    }
                } else if recognizer.sizeWhenBegan == .maximized {
                    if verticalVelocity > 0 {
                        setPreferredContentHeight(regularHeight, animated: true)
                    } else {
                        setPreferredContentHeight(maximizedHeight, animated: true)
                    }
                }
            }
        default:
            break
        }
    }
    
}

// MARK: - Embedded class
extension ConversationInputViewController {
    
    private enum Size {
        case minimized
        case regular
        case maximized
    }
    
    private class InteractiveResizeGestureRecognizer: UIPanGestureRecognizer {
        
        var sizeWhenBegan = Size.regular
        var beganInInputBar = false
        var shouldAdjustContentHeight = false
        
        override func reset() {
            super.reset()
            shouldAdjustContentHeight = false
        }
        
    }
    
}

// MARK: - UITextViewDelegate
extension ConversationInputViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return customInputViewController is ConversationInputInteractiveResizableViewController
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
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard !audioViewController.isRecording else {
            return false
        }
        let newText = (textView.text as NSString).replacingCharacters(in: range, with: text)
        if textView.text.isEmpty && !newText.isEmpty {
            layoutForInputTextViewIsEmpty(false, animated: true)
        } else if !textView.text.isEmpty && newText.isEmpty {
            layoutForInputTextViewIsEmpty(true, animated: true)
        }
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        guard let lineHeight = textView.font?.lineHeight else {
            return
        }
        let maxHeight = ceil(lineHeight * CGFloat(maxInputRow)
            + textView.textContainerInset.top
            + textView.textContainerInset.bottom)
        let sizeToFit = CGSize(width: textView.bounds.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let contentSize = textView.sizeThatFits(sizeToFit)
        inputTextView.isScrollEnabled = contentSize.height > maxHeight
        let newHeight = min(contentSize.height, maxHeight)
        let diff = newHeight - inputTextViewHeightConstraint.constant
        if abs(diff) > 0.1 {
            inputTextViewHeightConstraint.constant = newHeight
            setPreferredContentHeight(preferredContentSize.height + diff, animated: true)
            interactiveDismissResponder.height += diff
        }
    }
    
}

// MARK: - Private works
extension ConversationInputViewController {
    
    private func setPreferredContentHeight(_ height: CGFloat, animated: Bool) {
        if animated {
            preferredContentSize.height = height
        } else {
            UIView.performWithoutAnimation {
                preferredContentSize.height = height
            }
        }
    }
    
    private func resignTextViewFirstResponderWithoutReportingContentHeightChange() {
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
        customInputContainerView.layoutIfNeeded()
        if view.frame.height < regularHeight {
            setPreferredContentHeight(regularHeight, animated: true)
        }
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.customInputContainerView.alpha = 1
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
    
    private func layoutForInputTextViewIsEmpty(_ isEmpty: Bool, animated: Bool) {
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.2)
        }
        if isEmpty {
            beginEditingInputTextViewTrailingConstraint.priority = .defaultLow
            beginEditingRightActionsStackLeadingConstraint.priority = .defaultLow
            endEditingInputTextViewTrailingConstraint.priority = .defaultHigh
            endEditingRightActionsStackTrailingConstraint.priority = .defaultHigh
            inputBarView.layoutIfNeeded()
            sendButton.alpha = 0
            rightActionsStackView.alpha = 1
            audioInputContainerView.alpha = 1
            inputTextViewRightAccessoryView.alpha = 1
        } else {
            beginEditingInputTextViewTrailingConstraint.priority = .defaultHigh
            beginEditingRightActionsStackLeadingConstraint.priority = .defaultHigh
            endEditingInputTextViewTrailingConstraint.priority = .defaultLow
            endEditingRightActionsStackTrailingConstraint.priority = .defaultLow
            inputBarView.layoutIfNeeded()
            sendButton.alpha = 1
            rightActionsStackView.alpha = 0
            audioInputContainerView.alpha = 0
            inputTextViewRightAccessoryView.alpha = 0
        }
        if animated {
            UIView.commitAnimations()
        }
    }
    
    private func updateQuotePreview() {
        if let quote = quote {
            audioViewController.cancelIfRecording()
            UIView.performWithoutAnimation {
                quotePreviewView.render(message: quote.message, contentImageThumbnail: quote.thumbnail)
                quotePreviewView.layoutIfNeeded()
            }
            let heightChange = quotePreviewHeightConstraint.constant - quotePreviewWrapperHeightConstraint.constant
            quotePreviewWrapperHeightConstraint.constant = quotePreviewHeightConstraint.constant
            if inputTextView.isFirstResponder {
                if abs(heightChange) > 0 {
                    setPreferredContentHeight(preferredContentSize.height + heightChange, animated: true)
                }
            } else {
                inputTextView.becomeFirstResponder()
            }
        } else {
            if quotePreviewWrapperHeightConstraint.constant != 0 {
                let newHeight = preferredContentSize.height - quotePreviewWrapperHeightConstraint.constant
                quotePreviewWrapperHeightConstraint.constant = 0
                setPreferredContentHeight(newHeight, animated: true)
            }
        }
    }
    
    private func loadPhotoInput() {
        resignTextViewFirstResponderWithoutReportingContentHeightChange()
        photosButton.isSelected.toggle()
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
        case .authorized:
            performSynchronouslyOnMainThread(loadPhotoInput)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(handlePhotoAuthorizationStatus)
        case .denied, .restricted:
            alertSettings(Localized.PERMISSION_DENIED_PHOTO_LIBRARY)
        }
    }
    
}
