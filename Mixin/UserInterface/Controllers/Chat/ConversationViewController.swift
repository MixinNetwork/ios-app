import UIKit
import MobileCoreServices

class ConversationViewController: UIViewController {
    
    @IBOutlet weak var photoPreviewWrapperView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var connectionHintView: ConnectionHintView!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var announcementButton: UIButton!
    @IBOutlet weak var scrollToBottomWrapperView: UIView!
    @IBOutlet weak var scrollToBottomButton: UIButton!
    @IBOutlet weak var unreadBadgeLabel: UILabel!
    @IBOutlet weak var bottomBarWrapperView: UIView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var inputTextView: InputTextView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var toggleStickerPanelButton: UIButton!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var participantsLabel: UILabel!
    @IBOutlet weak var unblockButton: StateResponsiveButton!
    @IBOutlet weak var stickerPanelContainerView: UIView!
    @IBOutlet weak var moreMenuContainerView: UIView!
    @IBOutlet weak var dismissMoreMenuButton: UIButton!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var titleStackView: UIStackView!
    
    @IBOutlet weak var scrollToBottomWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputTextViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerPanelContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreMenuHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreMenuTopConstraint: NSLayoutConstraint!
    
    static var positions = [String: Position]()
    
    var dataSource: ConversationDataSource?
    private(set) var conversationId = ""
    
    private let maxInputRow = 6
    private let showScrollToBottomButtonThreshold: CGFloat = 150
    private let loadMoreMessageThreshold = 20
    private let animationDuration: TimeInterval = 0.25
    private let me = AccountAPI.shared.account!
    private let keyboardAnimationCurve = UIViewAnimationCurve(rawValue: 7) ?? .easeOut
    private let stickerPanelSegueId = "StickerPanelSegueId"
    private let moreMenuSegueId = "MoreMenuSegueId"
    
    private var ownerUser: UserItem?
    private var participants = [Participant]()
    private var role = ""
    private var asset: AssetItem?
    private var lastInputWrapperBottomConstant: CGFloat = 0
    private var isShowingMenu = false
    private var isShowingStickerPanel = false
    private var isAppearanceAnimating = true
    private var hideStatusBar = false
    
    private var tapRecognizer: UITapGestureRecognizer!
    private var reportRecognizer: UILongPressGestureRecognizer!
    private var stickerPanelViewController: StickerPanelViewController?
    private var moreMenuViewController: ConversationMoreMenuViewController?
    private var previewDocumentController: UIDocumentInteractionController?
    
    private(set) lazy var imagePickerController = ImagePickerController(initialCameraPosition: .rear, cropImageAfterPicked: false, parent: self)
    private lazy var userWindow = UserWindow.instance()
    private lazy var groupWindow = GroupWindow.instance()
    
    private lazy var photoPreviewViewController: PhotoPreviewViewController = {
        let controller = PhotoPreviewViewController.instance(conversationId: conversationId)
        controller.delegate = self
        addChildViewController(controller)
        photoPreviewWrapperView.addSubview(controller.view)
        controller.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        controller.didMove(toParentViewController: self)
        return controller
    }()
    private lazy var strangerTipsView: StrangerTipsView = {
        let view = StrangerTipsView()
        view.frame.size.height = StrangerTipsView.height
        view.blockButton.addTarget(self, action: #selector(blockAction(_:)), for: .touchUpInside)
        view.addContactButton.addTarget(self, action: #selector(addContactAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private var bottomSafeAreaInset: CGFloat {
        if #available(iOS 11.0, *) {
            return view.safeAreaInsets.bottom
        } else {
            return 0
        }
    }
    
    private var isShowingMoreMenu: Bool {
        return moreMenuTopConstraint.constant > 0.1
    }
    
    private var unreadBadgeValue: Int = 0 {
        didSet {
            guard unreadBadgeValue != oldValue else {
                return
            }
            unreadBadgeLabel.isHidden = unreadBadgeValue <= 0
            unreadBadgeLabel.text = unreadBadgeValue <= 99 ? String(unreadBadgeValue) : "99+"
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        showLoading()
        if let swipeBackRecognizer = navigationController?.interactivePopGestureRecognizer {
            tableView.gestureRecognizers?.forEach {
                $0.require(toFail: swipeBackRecognizer)
            }
        }
        if let conversation = dataSource?.conversation {
            titleLabel.text = conversation.getConversationName()
        } else if let ownerUser = ownerUser {
            titleLabel.text = ownerUser.fullName
        }
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapRecognizer.delegate = self
        tableView.addGestureRecognizer(tapRecognizer)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
        tableView.actionDelegate = self
        tableView.viewController = self
        inputTextView.delegate = self
        inputTextView.layer.cornerRadius = inputTextViewHeightConstraint.constant / 2
        connectionHintView.delegate = self
        loadStickerAndAsset()
        loadDraft()
        reportRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(showReportMenuAction))
        reportRecognizer.minimumPressDuration = 3
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(reportRecognizer)
        DispatchQueue.global().async { [weak self] in
            var conversation: ConversationItem?
            if let dataSource = self?.dataSource {
                if dataSource.category == .contact, self?.ownerUser == nil {
                    self?.ownerUser = UserDAO.shared.getUser(userId: dataSource.conversation.ownerId)
                }
            } else if let ownerUser = self?.ownerUser, let conversationId = self?.conversationId {
                conversation = ConversationDAO.shared.getConversation(conversationId: conversationId)
                if conversation == nil {
                    let item = ConversationItem()
                    item.conversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: ownerUser.userId)
                    item.name = ownerUser.fullName
                    item.iconUrl = ownerUser.avatarUrl
                    item.ownerId = ownerUser.userId
                    item.ownerIdentityNumber = ownerUser.identityNumber
                    item.category = ConversationCategory.CONTACT.rawValue
                    item.contentType = MessageCategory.SIGNAL_TEXT.rawValue
                    conversation = item
                }
            }
            var hasUnreadAnnouncement = false
            if let conversationId = self?.conversationId {
                hasUnreadAnnouncement = CommonUserDefault.shared.hasUnreadAnnouncement(conversationId: conversationId)
            }
            DispatchQueue.main.async {
                if let conversation = conversation {
                    self?.dataSource = ConversationDataSource(conversation: conversation)
                }
                if hasUnreadAnnouncement {
                    self?.announcementButton.isHidden = false
                }
                self?.prepareInterfaceAndObservers()
                self?.hideLoading()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == stickerPanelSegueId, let destination = segue.destination as? StickerPanelViewController {
            stickerPanelViewController = destination
        } else if segue.identifier == moreMenuSegueId, let destination = segue.destination as? ConversationMoreMenuViewController {
            moreMenuViewController = destination
        }
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if inputWrapperBottomConstraint.constant == 0 {
            inputWrapperBottomConstraint.constant = bottomSafeAreaInset
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isAppearanceAnimating = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isAppearanceAnimating = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissMenu(animated: true)
        isAppearanceAnimating = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveDraft()
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            if let lastIndexPath = dataSource?.lastIndexPath, visibleIndexPaths.contains(lastIndexPath) {
                ConversationViewController.positions[conversationId] = nil
            } else {
                for indexPath in visibleIndexPaths {
                    guard let message = dataSource?.viewModel(for: indexPath)?.message, !message.isExtensionMessage else {
                        continue
                    }
                    let rect = tableView.rectForRow(at: indexPath)
                    let offset = tableView.contentOffset.y - rect.origin.y
                    ConversationViewController.positions[conversationId] = Position(messageId: message.messageId, offset: offset)
                    break
                }
            }
        }
        if parent == nil {
            dataSource?.cancelMessageProcessing()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions
    @IBAction func profileAction(_ sender: Any) {
        if let dataSource = dataSource, dataSource.category == .group {
            groupWindow.updateGroup(conversation: dataSource.conversation).presentView()
        } else if let user = ownerUser {
            userWindow.updateUser(user: user).presentView()
        }
    }
    
    @IBAction func announcementAction(_ sender: Any) {
        guard let conversation = dataSource?.conversation, dataSource?.category == .group else {
            return
        }
        groupWindow.updateGroup(conversation: conversation, initialAnnouncementMode: .normal).presentView()
        CommonUserDefault.shared.setHasUnreadAnnouncement(false, forConversationId: conversationId)
        announcementButton.isHidden = true
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func scrollToBottomAction(_ sender: Any) {
        unreadBadgeValue = 0
        dataSource?.scrollToFirstUnreadMessageOrBottom()
    }
    
    @IBAction func moreAction(_ sender: Any) {
        var delay: TimeInterval = 0
        if isShowingStickerPanel {
            delay = animationDuration
            toggleStickerPanel(delay: 0)
        }
        if inputTextView.isFirstResponder {
            inputTextView.resignFirstResponder()
        }
        DispatchQueue.main.async {
            self.toggleMoreMenu(delay: delay)
        }
    }
    
    @IBAction func toggleStickerPanelAction(_ sender: Any) {
        inputTextView.resignFirstResponder()
        var delay: TimeInterval = 0
        if isShowingMoreMenu {
            toggleMoreMenu(delay: 0)
            delay = animationDuration
        }
        toggleStickerPanel(delay: delay)
    }
    
    @IBAction func sendTextMessageAction(_ sender: Any) {
        dataSource?.sendMessage(type: .SIGNAL_TEXT, value: trimmedMessageDraft)
        inputTextView.text = ""
        textViewDidChange(inputTextView)
    }
    
    @IBAction func dismissMoreMenuAction(_ sender: Any) {
        toggleMoreMenu(delay: 0)
    }
    
    @objc func showReportMenuAction() {
        guard !self.conversationId.isEmpty else {
            return
        }
        let conversationId = self.conversationId
        let alc = UIAlertController(title: Localized.REPORT_TITLE, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.REPORT_BUTTON, style: .default, handler: { [weak self](_) in
            self?.reportAction(conversationId: conversationId)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }

    @objc func blockAction(_ sender: Any) {
        guard let userId = ownerUser?.userId else {
            return
        }
        strangerTipsView.blockButton.isBusy = true
        UserAPI.shared.blockUser(userId: userId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerTipsView.blockButton.isBusy = false
            switch result {
            case .success(let userResponse):
                weakSelf.updateOwnerUser(withUserResponse: userResponse, updateDatabase: true)
            case let .failure(error, didHandled):
                guard !didHandled else {
                    return
                }
                weakSelf.alert(error.kind.localizedDescription ?? Localized.TOAST_OPERATION_FAILED)
            }
        }
    }
    
    @objc func unblockAction(_ sender: Any) {
        if !conversationId.isEmpty && unblockButton.title(for: .normal) == Localized.GROUP_MENU_DELETE {
            unblockButton.isBusy = true
            let conversationId = self.conversationId
            DispatchQueue.global().async { [weak self] in
                ConversationDAO.shared.makeQuitConversation(conversationId: conversationId)
                NotificationCenter.default.postOnMain(name: .ConversationDidChange)
                DispatchQueue.main.async {
                    self?.navigationController?.backToHome()
                }
            }
        } else {
            guard let user = ownerUser else {
                return
            }
            unblockButton.isBusy = true
            UserAPI.shared.unblockUser(userId: user.userId) { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.unblockButton.isBusy = false
                switch result {
                case .success(let userResponse):
                    weakSelf.updateOwnerUser(withUserResponse: userResponse, updateDatabase: true)
                case let .failure(error, didHandled):
                    guard !didHandled else {
                        return
                    }
                    weakSelf.alert(error.kind.localizedDescription ?? Localized.TOAST_OPERATION_FAILED)
                }
            }
        }
    }
    
    @objc func addContactAction(_ sender: Any) {
        guard let user = ownerUser else {
            return
        }
        strangerTipsView.addContactButton.isBusy = true
        UserAPI.shared.addFriend(userId: user.userId, full_name: user.fullName) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerTipsView.addContactButton.isBusy = false
            switch result {
            case .success(let userResponse):
                weakSelf.updateOwnerUser(withUserResponse: userResponse, updateDatabase: true)
            case let .failure(error, didHandled):
                guard !didHandled else {
                    return
                }
                weakSelf.alert(error.kind.localizedDescription ?? Localized.TOAST_OPERATION_FAILED)
            }
        }
    }
    
    @objc func tapAction(_ recognizer: UIGestureRecognizer) {
        guard !isShowingMenu else {
            dismissMenu(animated: true)
            return
        }
        guard !inputTextView.isFirstResponder else {
            inputTextView.resignFirstResponder()
            return
        }
        guard !isShowingStickerPanel else {
            toggleStickerPanel(delay: 0)
            return
        }
        guard let indexPath = tableView.indexPathForRow(at: recognizer.location(in: tableView)), let cell = tableView.cellForRow(at: indexPath), let message = dataSource?.viewModel(for: indexPath)?.message else {
            return
        }
        if message.category.hasSuffix("_IMAGE") {
            guard message.mediaStatus == MediaStatus.DONE.rawValue, let photoCell = cell as? PhotoMessageCell, photoCell.contentImageView.frame.contains(recognizer.location(in: photoCell)), let photo = Photo(message: message) else {
                return
            }
            view.bringSubview(toFront: photoPreviewWrapperView)
            photoPreviewViewController.show(photo: photo)
        } else if message.category.hasSuffix("_DATA") {
            guard let dataCell = cell as? DataMessageCell, dataCell.contentFrame.contains(recognizer.location(in: dataCell)), let mediaStatus = message.mediaStatus else {
                return
            }
            
            switch mediaStatus {
            case MediaStatus.DONE.rawValue:
                openDocumentAction(message: message)
            case MediaStatus.CANCELED.rawValue:
                MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
                if message.userId == me.user_id {
                    FileJobQueue.shared.addJob(job: FileUploadJob(message: Message.createMessage(message: message)))
                } else {
                    FileJobQueue.shared.addJob(job: FileDownloadJob(message: Message.createMessage(message: message)))
                }
            case MediaStatus.PENDING.rawValue:
                cancelMessageSending(message: message)
            default:
                break
            }
        } else if message.category.hasSuffix("_CONTACT") {
            guard let cell = cell as? ContactMessageCell, cell.contentFrame.contains(recognizer.location(in: cell)) else {
                return
            }
            guard let shareUserId = message.sharedUserId else {
                return
            }
            if shareUserId == AccountAPI.shared.accountUserId {
                navigationController?.pushViewController(withBackRoot: MyProfileViewController.instance())
            } else if let user = UserDAO.shared.getUser(userId: shareUserId) {
                userWindow.updateUser(user: user).presentView()
            }
        } else if message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
            guard let cell = cell as? SystemMessageCell, cell.contentFrame.contains(recognizer.location(in: cell)) else {
                return
            }
            open(url: .aboutEncryption)
        } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            DispatchQueue.global().async { [weak self] in
                guard let assetId = message.snapshotAssetId, let snapshotId = message.snapshotId, let asset = AssetDAO.shared.getAsset(assetId: assetId), let snapshot = SnapshotDAO.shared.getSnapshot(snapshotId: snapshotId) else {
                    return
                }
                DispatchQueue.main.async {
                    self?.navigationController?.pushViewController(TransactionViewController.instance(asset: asset, snapshot: snapshot), animated: true)
                }
            }
        } else if message.category == MessageCategory.APP_CARD.rawValue {
            guard let action = message.appCard?.action else {
                return
            }
            open(url: action)
        }
    }
    
    // MARK: - Callbacks
    @objc func conversationDidChange(_ sender: Notification) {
        guard let change = sender.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case let .updateGroupIcon(iconUrl):
            avatarImageView?.setGroupImage(with: iconUrl, conversationId: conversationId)
        case .update:
            hideLoading()
        case let .updateConversation(conversation):
            if !conversation.name.isEmpty {
                titleLabel.text = conversation.name
                dataSource?.conversation.name = conversation.name
            }
            dataSource?.conversation.announcement = conversation.announcement
            announcementButton.isHidden = !CommonUserDefault.shared.hasUnreadAnnouncement(conversationId: conversationId)
            hideLoading()
        case .startedUpdateConversation:
            showLoading()
        default:
            break
        }
    }
    
    @objc func userDidChange(_ sender: Notification) {
        if let userResponse = sender.object as? UserResponse, userResponse.userId == self.ownerUser?.userId {
            updateOwnerUser(withUserResponse: userResponse, updateDatabase: false)
        } else if let user = sender.object as? UserItem, user.userId == self.ownerUser?.userId {
            self.ownerUser = user
            updateNavigationBar()
            updateBottomView()
            updateStrangerTipsView()
        }
        hideLoading()
        dataSource?.ownerUser = ownerUser
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard !isAppearanceAnimating else {
            return
        }
        let endFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let duration = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? animationDuration
        let windowHeight = AppDelegate.current.window!.bounds.height
        inputWrapperBottomConstraint.constant = max(windowHeight - endFrame.origin.y, bottomSafeAreaInset)
        let inputWrapperDisplacement = lastInputWrapperBottomConstant - inputWrapperBottomConstraint.constant
        let keyboardIsMovingUp = inputWrapperBottomConstraint.constant > 0
        if isShowingStickerPanel && keyboardIsMovingUp {
            stickerPanelContainerView.alpha = 0
            isShowingStickerPanel = false
        }
        if isShowingMoreMenu {
            toggleMoreMenu(delay: 0)
        }
        let y = max(0, tableView.contentOffset.y - inputWrapperDisplacement)
        lastInputWrapperBottomConstant = inputWrapperBottomConstraint.constant
        UIView.animate(withDuration: duration) {
            if let rawValue = notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? Int, let curve = UIViewAnimationCurve(rawValue: rawValue) {
                UIView.setAnimationCurve(curve)
            }
            self.tableView.contentOffset.y = y
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func menuControllerDidShowMenu(_ notification: Notification) {
        isShowingMenu = true
    }
    
    @objc func menuControllerDidHideMenu(_ notification: Notification) {
        isShowingMenu = false
        inputTextView.overrideNext = nil
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.object as? String, conversationId == self.conversationId else {
            return
        }
        updateMoreMenuApps()
        reloadParticipants()
    }
    
    @objc func assetsDidChange(_ notification: Notification) {
        DispatchQueue.global().async { [weak self] in
            self?.asset = AssetDAO.shared.getAvailableAssetId(assetId: WalletUserDefault.shared.defalutTransferAssetId)
        }
    }
    
    @objc func didAddedMessagesOutsideVisibleBounds(_ notification: Notification) {
        guard let count = notification.object as? Int else {
            return
        }
        unreadBadgeValue += count
    }
    
    @objc func applicationWillTerminate(_ notification: Notification) {
        saveDraft()
    }
    
    // MARK: - Interface
    func toggleMoreMenu(delay: TimeInterval) {
        let dismissButtonAlpha: CGFloat
        if isShowingMoreMenu {
            moreMenuTopConstraint.constant = 0
            dismissButtonAlpha = 0
        } else {
            moreMenuTopConstraint.constant = moreMenuViewController?.contentHeight ?? moreMenuHeightConstraint.constant
            dismissButtonAlpha = 0.3
        }
        UIView.animate(withDuration: animationDuration, delay: delay, options: [], animations: {
            UIView.setAnimationCurve(self.keyboardAnimationCurve)
            self.dismissMoreMenuButton.alpha = dismissButtonAlpha
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func documentAction() {
        let vc = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .import)
        vc.delegate = self
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true, completion: nil)
    }
    
    func transferAction() {
        guard let user = ownerUser else {
            return
        }
        let viewController: UIViewController
        if AccountAPI.shared.account?.has_pin ?? false {
            viewController = TransferViewController.instance(user: user, conversationId: conversationId, asset: asset)
        } else {
            viewController = WalletPasswordViewController.instance(fromChat:  user, conversationId: conversationId, asset: asset)
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    // MARK: - Class func
    class func instance(conversation: ConversationItem, highlight: ConversationDataSource.Highlight? = nil) -> ConversationViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "conversation") as! ConversationViewController
        vc.dataSource = ConversationDataSource(conversation: conversation, highlight: highlight)
        vc.conversationId = conversation.conversationId
        return vc
    }
    
    class func instance(ownerUser: UserItem) -> ConversationViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "conversation") as! ConversationViewController
        vc.ownerUser = ownerUser
        vc.conversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: ownerUser.userId)
        return vc
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension ConversationViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if isShowingMenu {
            return true
        }
        if let view = touch.view as? TextMessageLabel {
            return !view.canResponseTouch(at: touch.location(in: view))
        }
        return true
    }
    
}

// MARK: - UITextViewDelegate
extension ConversationViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        guard let lineHeight = textView.font?.lineHeight else {
            return
        }
        let maxHeight = ceil(lineHeight * CGFloat(maxInputRow) + textView.textContainerInset.top + textView.textContainerInset.bottom)
        let contentSize = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: UILayoutFittingExpandedSize.height))
        inputTextView.isScrollEnabled = contentSize.height > maxHeight
        if trimmedMessageDraft.isEmpty {
            sendButton.isHidden = true
            toggleStickerPanelButton.isHidden = false
        } else {
            sendButton.isHidden = false
            toggleStickerPanelButton.isHidden = true
        }
        let newHeight = min(contentSize.height, maxHeight)
        if abs(newHeight - inputTextViewHeightConstraint.constant) > 0.1 {
            let newContentOffset = CGPoint(x: tableView.contentOffset.x,
                                           y: tableView.contentOffset.y - (inputTextViewHeightConstraint.constant - newHeight))
            inputTextViewHeightConstraint.constant = newHeight
            UIView.animate(withDuration: animationDuration, animations: {
                self.tableView.setContentOffset(newContentOffset, animated: false)
                self.view.layoutIfNeeded()
            })
        }
    }
    
}

// MARK: - ConnectionHintViewDelegate
extension ConversationViewController: ConnectionHintViewDelegate {
    
    func animateAlongsideConnectionHintView(_ view: ConnectionHintView, changingHeightWithDifference heightDifference: CGFloat) {
        tableView.contentOffset.y += heightDifference
    }
    
}

// MARK: - UITableViewDataSource
extension ConversationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource?.viewModels(for: section)?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return self.tableView.dequeueReusableCell(withMessageCategory: MessageCategory.UNKNOWN.rawValue, for: indexPath)
        }
        let cell = self.tableView.dequeueReusableCell(withMessage: viewModel.message, for: indexPath)
        if let cell = cell as? MessageCell {
            UIView.performWithoutAnimation {
                cell.render(viewModel: viewModel)
            }
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource?.dates.count ?? 0
    }
    
}

// MARK: - ConversationTableViewActionDelegate
extension ConversationViewController: ConversationTableViewActionDelegate {
    
    func conversationTableViewCanBecomeFirstResponder(_ tableView: ConversationTableView) -> Bool {
        return !inputTextView.isFirstResponder
    }
    
    func conversationTableViewLongPressWillBegan(_ tableView: ConversationTableView) {
        inputTextView.overrideNext = tableView
    }
    
    func conversationTableView(_ tableView: ConversationTableView, hasActionsforIndexPath indexPath: IndexPath) -> Bool {
        guard let message = dataSource?.viewModel(for: indexPath)?.message else {
            return false
        }
        return !message.allowedActions.isEmpty
    }
    
    func conversationTableView(_ tableView: ConversationTableView, canPerformAction action: Selector, forIndexPath indexPath: IndexPath) -> Bool {
        guard let message = dataSource?.viewModel(for: indexPath)?.message else {
            return false
        }
        return message.allowedActions.contains(action)
    }
    
    func conversationTableView(_ tableView: ConversationTableView, didSelectAction action: ConversationTableView.Action, forIndexPath indexPath: IndexPath) {
        guard let message = dataSource?.viewModel(for: indexPath)?.message else {
            return
        }
        switch action {
        case .copy:
            if message.category.hasSuffix("_TEXT") {
                UIPasteboard.general.string = message.content
            }
        case .delete:
            cancelMessageSending(message: message)
            dataSource?.queue.async { [weak self] in
                MessageDAO.shared.deleteMessage(id: message.messageId)
                DispatchQueue.main.sync {
                    guard let weakSelf = self else {
                        return
                    }
                    if let (didRemoveRow, didRemoveSection) = weakSelf.dataSource?.removeViewModel(at: indexPath) {
                        if didRemoveSection {
                            weakSelf.tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
                        } else if didRemoveRow {
                            weakSelf.tableView.deleteRows(at: [indexPath], with: .fade)
                        }
                    }
                    weakSelf.updateHeaderViews(animated: true)
                }
            }
        case .forward:
            navigationController?.pushViewController(ForwardViewController.instance(message: message, ownerUser: ownerUser), animated: true)
        case .reply:
            break
        }
    }
}

// MARK: - UITableViewDelegate
extension ConversationViewController: UITableViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateAccessoryButtons(animated: !isAppearanceAnimating)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if isShowingStickerPanel {
            toggleStickerPanel(delay: 0)
        }
        UIView.animate(withDuration: animationDuration) {
            self.updateHeaderViews(animated: false)
            self.dismissMenu(animated: false)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateHeaderViews(animated: true)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard !tableView.isTracking else {
            return
        }
        updateHeaderViews(animated: true)
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        return false
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateHeaderViews(animated: true)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let dataSource = dataSource else {
            return
        }
        if indexPath.section == 0 && indexPath.row <= loadMoreMessageThreshold {
            dataSource.loadMoreAboveIfNeeded()
        } else if let lastIndexPath = dataSource.lastIndexPath, indexPath.section == lastIndexPath.section, indexPath.row >= lastIndexPath.row - loadMoreMessageThreshold {
            dataSource.loadMoreBelowIfNeeded()
        }
        if dataSource.viewModel(for: indexPath)?.message.messageId == dataSource.firstUnreadMessageId || cell is UnreadHintMessageCell {
            unreadBadgeValue = 0
            dataSource.firstUnreadMessageId = nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return 44
        }
        if viewModel.cellHeight.isNaN || viewModel.cellHeight < 1 {
            UIApplication.trackError("ConversationViewController", action: "Invalid row height", userInfo: ["viewModel": viewModel.debugDescription])
            return 44
        } else {
            return viewModel.cellHeight
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return ConversationDateHeaderView.height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ConversationTableView.ReuseId.header.rawValue) as! ConversationDateHeaderView
        if let date = dataSource?.dates[section] {
            header.label.text = DateFormatter.yyyymmdd.date(from: date)?.timeDayAgo()
        }
        return header
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
    
}

// MARK: - DetailInfoMessageCellDelegate
extension ConversationViewController: DetailInfoMessageCellDelegate {
    
    func detailInfoMessageCellDidSelectFullname(_ cell: DetailInfoMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let message = dataSource?.viewModel(for: indexPath)?.message, let user = UserDAO.shared.getUser(userId: message.userId) else {
            return
        }
        userWindow.updateUser(user: user).presentView()
    }
    
}

// MARK: - AppButtonGroupMessageCellDelegate
extension ConversationViewController: AppButtonGroupMessageCellDelegate {
    
    func appButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, didSelectActionAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell), let appButtons = dataSource?.viewModel(for: indexPath)?.message.appButtons, index < appButtons.count else {
            return
        }
        let appButton = appButtons[index]
        if let url = URL(string: appButton.action) {
            open(url: url)
        }
    }
    
}

// MARK: - DataMessageCellDelegate
extension ConversationViewController: DataMessageCellDelegate {
    
    func dataMessageCellDidSelectNetworkOperation(_ cell: DataMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        let message = viewModel.message
        operationAction(message: message, operationButton: cell.operationButton)
    }
    
}

// MARK: - PhotoMessageCellDelegate
extension ConversationViewController: PhotoMessageCellDelegate {
    
    func photoMessageCellDidSelectNetworkOperation(_ cell: PhotoMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        let message = viewModel.message
        if case .download = cell.operationButton.style {
            cell.downloadPhoto(message: message)
        }
        operationAction(message: message, operationButton: cell.operationButton)
    }
    
    private func operationAction(message: MessageItem, operationButton: NetworkOperationButton) {
        switch operationButton.style {
        case .finished, .expired:
            break
        case .upload:
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
            if message.category.hasSuffix("_DATA") {
                FileJobQueue.shared.addJob(job: FileUploadJob(message: Message.createMessage(message: message)))
            } else if message.category.hasSuffix("_IMAGE") {
                ConcurrentJobQueue.shared.addJob(job: AttachmentUploadJob(message: Message.createMessage(message: message)))
            }
        case .download:
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .PENDING, conversationId: message.conversationId)
            if message.category.hasSuffix("_DATA") {
                FileJobQueue.shared.addJob(job: FileDownloadJob(message: Message.createMessage(message: message)))
            }
        case .busy:
            cancelMessageSending(message: message)
        }
    }
}

// MARK: - CoreTextLabelDelegate
extension ConversationViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        open(url: url)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_OPEN_URL, style: .default, handler: { [weak self](_) in
            self?.open(url: url)
        }))
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_MENU_COPY, style: .default, handler: { (_) in
            UIPasteboard.general.string = url.absoluteString
            NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.TOAST_COPIED)
        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - ImagePickerControllerDelegate
extension ConversationViewController: ImagePickerControllerDelegate {
    
    func imagePickerController(_ controller: ImagePickerController, didPickImage image: UIImage) {
        dataSource?.sendMessage(type: .SIGNAL_IMAGE, value: image.scaleForUpload())
    }
    
}

// MARK: - UIDocumentPickerDelegate
extension ConversationViewController: UIDocumentPickerDelegate {
    
    @available(iOS 11.0, *)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard urls.count > 0 else {
            return
        }
        documentPicker(controller, didPickDocumentAt: urls[0])
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        dataSource?.sendMessage(type: .SIGNAL_DATA, value: url)
    }
    
}

// MARK: - UIDocumentInteractionControllerDelegate
extension ConversationViewController: UIDocumentInteractionControllerDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        previewDocumentController = nil
    }
    
}

// MARK: - PhotoPreviewViewControllerDelegate
extension ConversationViewController: PhotoPreviewViewControllerDelegate {
    
    func placeholder(forMessageId id: String) -> UIImage? {
        if let indexPath = dataSource?.indexPath(where: { $0.messageId == id }), let cell = tableView.cellForRow(at: indexPath) as? PhotoMessageCell {
            return cell.contentImageView.image
        } else {
            return nil
        }
    }
    
    func sourceFrame(forMessageId id: String) -> CGRect? {
        if let indexPath = dataSource?.indexPath(where: { $0.messageId == id }), let cell = tableView.cellForRow(at: indexPath) as? PhotoMessageCell {
            return cell.contentImageView.convert(cell.contentImageView.bounds, to: view)
        } else {
            return nil
        }
    }
    
    func sourceView(forMessageId id: String) -> UIView? {
        if let indexPath = dataSource?.indexPath(where: { $0.messageId == id }), let cell = tableView.cellForRow(at: indexPath) as? PhotoMessageCell {
            return cell.contentView
        } else {
            return nil
        }
    }
    
    func snapshotView(forMessageId id: String) -> UIView? {
        if let indexPath = dataSource?.indexPath(where: { $0.messageId == id }), let cell = tableView.cellForRow(at: indexPath) as? PhotoMessageCell {
            return cell.contentSnapshotView(afterScreenUpdates: false)
        } else {
            return nil
        }
    }
    
    func animateAlongsideAppearance() {
        hideStatusBar = true
        setNeedsStatusBarAppearanceUpdate()
    }
    
    func animateAlongsideDisappearance() {
        hideStatusBar = false
        setNeedsStatusBarAppearanceUpdate()
    }
    
    func viewControllerDidDismissed(_ viewController: PhotoPreviewViewController) {
        view.sendSubview(toBack: photoPreviewWrapperView)
    }

}

// MARK: - UI Related Helpers
extension ConversationViewController {
    
    private func updateNavigationBar() {
        if let dataSource = dataSource, dataSource.category == .group {
            let conversation = dataSource.conversation
            titleLabel.text = conversation.name
            avatarImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
        } else {
            guard let user = ownerUser else {
                return
            }
            participantsLabel.text = user.identityNumber
            titleLabel.text = user.fullName
            avatarImageView.setImage(with: user)
        }
    }
    
    private func updateOwnerUser(withUserResponse userResponse: UserResponse, updateDatabase: Bool) {
        if updateDatabase {
            UserDAO.shared.updateUsers(users: [userResponse], sendNotificationAfterFinished: false)
        }
        ownerUser = UserItem.createUser(from: userResponse)
        updateNavigationBar()
        updateBottomView()
        updateStrangerTipsView()
    }
    
    private func updateBottomView() {
        guard let user = ownerUser else {
            return
        }
        unblockButton.isHidden = user.relationship != Relationship.BLOCKING.rawValue
    }
    
    private func updateMoreMenuFixedJobs() {
        if dataSource?.category == .contact, let ownerUser = ownerUser, !ownerUser.isBot {
            moreMenuViewController?.fixedJobs = [.camera, .photo, .file, .transfer]
        } else {
            moreMenuViewController?.fixedJobs = [.camera, .photo, .file]
        }
    }
    
    private func updateMoreMenuApps() {
        if Thread.isMainThread {
            DispatchQueue.global().async { [weak self] in
                self?.updateMoreMenuApps()
            }
        } else {
            if dataSource?.category == .group {
                moreMenuViewController?.apps = AppDAO.shared.getConversationBots(conversationId: conversationId)
            } else {
                guard let ownerId = ownerUser?.userId, let userBot = AppDAO.shared.getUserBot(userId: ownerId) else {
                    return
                }
                moreMenuViewController?.apps = [userBot]
            }
        }
    }
    
    private func updateAccessoryButtons(animated: Bool) {
        let position = tableView.contentSize.height - tableView.contentOffset.y - tableView.bounds.height
        if scrollToBottomWrapperView.alpha < 0.1 && position > showScrollToBottomButtonThreshold {
            scrollToBottomWrapperHeightConstraint.constant = 48
            if animated {
                UIView.beginAnimations(nil, context: nil)
                UIView.setAnimationDuration(animationDuration)
            }
            scrollToBottomWrapperView.alpha = 1
            if animated {
                view.layoutIfNeeded()
                UIView.commitAnimations()
            }
        } else if scrollToBottomWrapperView.alpha > 0.9 && position < showScrollToBottomButtonThreshold {
            scrollToBottomWrapperHeightConstraint.constant = 4
            if animated {
                UIView.beginAnimations(nil, context: nil)
                UIView.setAnimationDuration(animationDuration)
            }
            scrollToBottomWrapperView.alpha = 0
            if animated {
                view.layoutIfNeeded()
                UIView.commitAnimations()
            }
            unreadBadgeValue = 0
            dataSource?.firstUnreadMessageId = nil
        }
    }
    
    private func dismissMenu(animated: Bool) {
        guard UIMenuController.shared.isMenuVisible else {
            return
        }
        UIMenuController.shared.setMenuVisible(false, animated: animated)
    }
    
    private func toggleStickerPanel(delay: TimeInterval) {
        inputWrapperBottomConstraint.constant = isShowingStickerPanel ? bottomSafeAreaInset : stickerPanelContainerHeightConstraint.constant
        let newAlpha: CGFloat = isShowingStickerPanel ? 0 : 1
        let offset = inputWrapperBottomConstraint.constant - lastInputWrapperBottomConstant
        UIView.animate(withDuration: animationDuration, delay: delay, options: [], animations: {
            UIView.setAnimationCurve(self.keyboardAnimationCurve)
            self.stickerPanelContainerView.alpha = newAlpha
            self.tableView.contentOffset.y = max(0, self.tableView.contentOffset.y + offset)
            self.view.layoutIfNeeded()
        }) { (_) in
            self.isShowingStickerPanel = !self.isShowingStickerPanel
            self.lastInputWrapperBottomConstant = self.inputWrapperBottomConstraint.constant
        }
    }
    
    private func updateHeaderViews(animated: Bool) {
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(animationDuration)
        }
        var headerViews = tableView.headerViews
        if tableView.isTracking {
            headerViews.forEach {
                $0.contentAlpha = 1
            }
        } else {
            if let firstIndexPath = tableView.indexPathsForVisibleRows?.first,
                let firstCell = tableView.cellForRow(at: firstIndexPath),
                let headerView = tableView.headerView(forSection: firstIndexPath.section) as? ConversationDateHeaderView,
                headerView.frame.intersects(firstCell.frame) {
                if let index = headerViews.index(of: headerView) {
                    headerViews.remove(at: index)
                }
                headerView.contentAlpha = 0
            }
            headerViews.forEach {
                $0.contentAlpha = 1
            }
        }
        if animated {
            UIView.commitAnimations()
        }
    }
    
    private func updateStrangerTipsView() {
        DispatchQueue.global().async { [weak self] in
            if let ownerUser = self?.ownerUser, ownerUser.relationship == Relationship.STRANGER.rawValue, !MessageDAO.shared.hasSentMessage(toUserId: ownerUser.userId) {
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.tableView.tableFooterView = weakSelf.strangerTipsView
                }
            } else {
                DispatchQueue.main.async {
                    self?.tableView.tableFooterView = nil
                }
            }
        }
    }
    
}

// MARK: - Helpers
extension ConversationViewController {
    
    private var trimmedMessageDraft: String {
        return inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func prepareInterfaceAndObservers() {
        dataSource?.ownerUser = ownerUser
        dataSource?.tableView = tableView
        dataSource?.initData()
        dataSource?.queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.updateAccessoryButtons(animated: false)
            }
        }
        updateMoreMenuFixedJobs()
        updateMoreMenuApps()
        updateStrangerTipsView()
        updateBottomView()
        bottomBarWrapperView.isHidden = false
        updateNavigationBar()
        reloadParticipants()
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userDidChange(_:)), name: .UserDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidShowMenu(_:)), name: .UIMenuControllerDidShowMenu, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidHideMenu(_:)), name: .UIMenuControllerDidHideMenu, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: .AssetsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didAddedMessagesOutsideVisibleBounds(_:)), name: Notification.Name.ConversationDataSource.DidAddedMessagesOutsideVisibleBounds, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: .UIApplicationWillTerminate, object: nil)
    }
    
    private func saveDraft() {
        guard !conversationId.isEmpty else {
            return
        }
        CommonUserDefault.shared.setConversationDraft(conversationId, draft: trimmedMessageDraft)
    }
    
    private func loadDraft() {
        let draft = CommonUserDefault.shared.getConversationDraft(conversationId)
        if !draft.isEmpty {
            inputTextView.text = draft
            textViewDidChange(inputTextView)
        }
    }
    
    private func reloadParticipants() {
        guard dataSource?.category == .group else {
            return
        }
        if Thread.isMainThread {
            participantsLabel.text = Localized.GROUP_SECTION_TITLE_MEMBERS(count: 0)
        }
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            if ParticipantDAO.shared.isExistParticipant(conversationId: conversationId) {
                let participants = ParticipantDAO.shared.participants(conversationId: conversationId)
                self?.role = participants.first(where: { $0.userId == AccountAPI.shared.accountUserId })?.role ?? ""
                self?.participants = participants
                DispatchQueue.main.async { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.unblockButton.isHidden = true
                    if weakSelf.dataSource?.category == .group {
                        weakSelf.participantsLabel.text = Localized.GROUP_SECTION_TITLE_MEMBERS(count: weakSelf.participants.count)
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.participantsLabel.text = Localized.GROUP_REMOVE_TITLE
                    weakSelf.unblockButton.setTitle(Localized.GROUP_MENU_DELETE, for: .normal)
                    weakSelf.unblockButton.isHidden = false
                }
            }
        }
    }
    
    private func loadStickerAndAsset() {
        let containerWidth = AppDelegate.current.window!.bounds.width
        DispatchQueue.global().async { [weak self] in
            let albums = StickerAlbumDAO.shared.getAlbums()
            var stickers = albums.map{ StickerDAO.shared.getStickers(albumId: $0.albumId) }
            let limit = StickerPageViewController.numberOfRecentStickers(forLayoutWidth: containerWidth)
            stickers.insert(StickerDAO.shared.recentUsedStickers(limit: limit), at: 0)
            DispatchQueue.main.async {
                self?.stickerPanelViewController?.reload(albums: albums, stickers: stickers)
            }
            
            self?.asset = AssetDAO.shared.getAvailableAssetId(assetId: WalletUserDefault.shared.defalutTransferAssetId)
        }
    }
    
    private func openDocumentAction(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        let url = MixinFile.chatFilesUrl.appendingPathComponent(mediaUrl)
        guard FileManager.default.fileExists(atPath: url.path)  else {
            UIApplication.trackError("ConversationViewController", action: "openDocumentAction file not exist")
            return
        }
        previewDocumentController = UIDocumentInteractionController(url: url)
        previewDocumentController?.delegate = self
        if !(previewDocumentController?.presentPreview(animated: true) ?? false) {
            previewDocumentController?.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
        }
    }
    
    private func cancelMessageSending(message: MessageItem) {
        let sentByMe = message.userId == me.user_id
        let jobId: String
        if message.category.hasSuffix("_IMAGE") {
            if sentByMe {
                jobId = AttachmentUploadJob.jobId(messageId: message.messageId)
            } else {
                jobId = AttachmentDownloadJob.jobId(messageId: message.messageId)
            }
            ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        } else if message.category.hasSuffix("_DATA") {
            if sentByMe {
                jobId = FileUploadJob.fileJobId(messageId: message.messageId)
            } else {
                jobId = FileDownloadJob.fileJobId(messageId: message.messageId)
            }
            FileJobQueue.shared.cancelJob(jobId: jobId)
        } else {
            return
        }
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .CANCELED, conversationId: message.conversationId)
    }
    
    private func reportAction(conversationId: String) {
        DispatchQueue.global().async { [weak self] in
            let developID = AccountAPI.shared.accountIdentityNumber == "762532" ? "31911" : "762532"
            var user = UserDAO.shared.getUser(identityNumber: developID)
            if user == nil {
                switch UserAPI.shared.search(keyword: developID) {
                case let .success(userResponse):
                    UserDAO.shared.updateUsers(users: [userResponse])
                    user = UserItem.createUser(from: userResponse)
                case .failure:
                    return
                }
            }
            guard let developUser = user, let url = FileManager.default.exportLog(conversationId: conversationId) else {
                return
            }
            let targetUrl = MixinFile.chatFilesUrl.appendingPathComponent(url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: targetUrl)
                try FileManager.default.removeItem(at: url)
            } catch {
                return
            }
            guard FileManager.default.fileSize(targetUrl.path) > 0 else {
                return
            }
            
            let developConversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: developUser.userId)
            var message = Message.createMessage(category: MessageCategory.SIGNAL_DATA.rawValue, conversationId: developConversationId, userId: AccountAPI.shared.accountUserId)
            message.name = url.lastPathComponent
            message.mediaSize = FileManager.default.fileSize(targetUrl.path)
            message.mediaMineType = FileManager.default.mimeType(ext: url.pathExtension)
            message.mediaUrl = url.lastPathComponent
            message.mediaStatus = MediaStatus.PENDING.rawValue
            
            self?.dataSource?.queue.async {
                SendMessageService.shared.sendMessage(message: message, ownerUser: developUser, isGroupMessage: false)
                DispatchQueue.main.async {
                    self?.navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: developUser))
                }
            }
        }
    }

    private func showLoading() {
        loadingView.isHidden = false
        loadingView.startAnimating()
        titleStackView.isHidden = true
    }

    private func hideLoading() {
        loadingView.isHidden = true
        loadingView.stopAnimating()
        titleStackView.isHidden = false
    }
    
    private func open(url: URL) {
        guard !UrlWindow.checkUrl(url: url) else {
            return
        }
        guard !conversationId.isEmpty else {
            return
        }
        WebWindow.instance(conversationId: conversationId).presentPopupControllerAnimated(url: url)
    }
    
}

// MARK: - Embedded classes
extension ConversationViewController {
    
    struct Position {
        let messageId: String
        let offset: CGFloat
    }
    
}
