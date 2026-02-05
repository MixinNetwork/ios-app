import UIKit
import MobileCoreServices
import AVKit
import SDWebImage
import MixinServices

final class ConversationViewController: UIViewController {
    
    static var positions = [String: Position]()
    static var allowReportSingleMessage = false
    
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var navigationBarContentView: UIView!
    @IBOutlet weak var wallpaperImageView: WallpaperImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var membershipIconView: SDAnimatedImageView!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var accessoryButtonsWrapperView: HittestBypassWrapperView!
    @IBOutlet weak var mentionWrapperView: UIView!
    @IBOutlet weak var mentionCountLabel: InsetLabel!
    @IBOutlet weak var scrollToBottomWrapperView: UIView!
    @IBOutlet weak var scrollToBottomButton: UIButton!
    @IBOutlet weak var unreadBadgeLabel: InsetLabel!
    @IBOutlet weak var announcementBadgeView: UIView!
    @IBOutlet weak var inputWrapperView: UIView!
    @IBOutlet weak var inputWrapperTopShadowView: TopShadowView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var titleStackView: UIStackView!
    
    @IBOutlet weak var navigationBarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var mentionWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollToBottomWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var accessoryButtonsWrapperTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var accessoryButtonsWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var announcementBadgeHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var showInputWrapperConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideInputWrapperConstraint: NSLayoutConstraint!
    
    var dataSource: ConversationDataSource!
    var composer: ConversationMessageComposer!
    var conversationId: String {
        return dataSource.conversationId
    }
    var statusBarHidden = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    // Margin to navigation title bar
    private let minInputWrapperTopMargin: CGFloat = {
        if ScreenHeight.current <= .short {
            return 60
        } else {
            return 112
        }
    }()
    
    private let showScrollToBottomButtonThreshold: CGFloat = 150
    private let loadMoreMessageThreshold = 20
    private let animationDuration: TimeInterval = 0.3
    private let fastReplyConfirmedDistance: CGFloat = 30
    private let fastReplyMaxDistance: CGFloat = 60
    private let feedback = UIImpactFeedbackGenerator()
    private let pinMessageBannerHeight: CGFloat = 60
    
    private var ownerUser: UserItem?
    private var quotingMessageId: String?
    private var isAppearanceAnimating = true
    private var adjustTableViewContentOffsetWhenInputWrapperHeightChanges = true
    private var didManuallyStoppedTableViewDecelerating = false
    private var numberOfParticipants: Int?
    private var isMember = true
    private var messageIdToFlashAfterAnimationFinished: String?
    private var tapRecognizer: UITapGestureRecognizer!
    private var reportRecognizer: UILongPressGestureRecognizer!
    private var resizeInputRecognizer: ResizeInputWrapperGestureRecognizer!
    private var fastReplyRecognizer: FastReplyGestureRecognizer!
    private var textPreviewRecognizer: UITapGestureRecognizer!
    private var conversationInputViewController: ConversationInputViewController!
    private var previewDocumentController: UIDocumentInteractionController?
    private var previewDocumentMessageId: String?
    private var myInvitation: Message?
    private var isShowingKeyboard = false
    private var groupCallIndicatorCenterYConstraint: NSLayoutConstraint?
    private var makeInputTextViewFirstResponderOnAppear = false
    private var canPinMessages = false
    private var pinnedMessageIds = Set<String>()
    private var lastMentionCandidate: String?
    
    private weak var pinMessageBannerViewIfLoaded: PinMessageBannerView?
    private weak var groupCallIndicatorViewIfLoaded: GroupCallIndicatorView?
    private weak var membershipButton: UIButton?
    
    private lazy var userHandleViewController = R.storyboard.chat.user_handle()!
    private lazy var multipleSelectionActionView = R.nib.multipleSelectionActionView(withOwner: self)!
    private lazy var announcementBadgeContentView = R.nib.announcementBadgeContentView(withOwner: self)!
    
    private lazy var strangerHintView: StrangerHintView = {
        let view = R.nib.strangerHintView(withOwner: nil)!
        view.blockButton.addTarget(self, action: #selector(blockAction(_:)), for: .touchUpInside)
        view.addContactButton.addTarget(self, action: #selector(addContactAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var appReceptionView: AppReceptionView = {
        let view = R.nib.appReceptionView(withOwner: nil)!
        view.openHomePageButton.addTarget(conversationInputViewController,
                                          action: #selector(ConversationInputViewController.openOpponentAppAction(_:)),
                                          for: .touchUpInside)
        view.greetingButton.addTarget(self, action: #selector(greetAppAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var invitationHintView: InvitationHintView = {
        let view = R.nib.invitationHintView(withOwner: nil)!
        view.exitButton.addTarget(self, action: #selector(exitGroupAndReportInviterAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var groupCallIndicatorView: GroupCallIndicatorView = {
        let indicator = R.nib.groupCallIndicatorView(withOwner: self)!
        indicator.isHidden = true
        if let banner = pinMessageBannerViewIfLoaded {
            view.insertSubview(indicator, aboveSubview: banner)
        } else {
            view.addSubview(indicator)
        }
        indicator.snp.makeConstraints { (make) in
            make.trailing.equalToSuperview()
        }
        let constraint = indicator.centerYAnchor.constraint(equalTo: view.topAnchor)
        constraint.constant = groupCallIndicatorCenterYLimitation.min
        constraint.isActive = true
        
        groupCallIndicatorViewIfLoaded = indicator
        groupCallIndicatorCenterYConstraint = constraint
        return indicator
    }()
    
    private lazy var cancelSelectionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .background
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16),
                                   adjustForContentSize: true)
        button.setTitleColor(.theme, for: .normal)
        button.setTitle(R.string.localizable.cancel(), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        button.addTarget(self, action: #selector(endMultipleSelection), for: .touchUpInside)
        return button
    }()
    
    private lazy var pinMessageBannerView: PinMessageBannerView = {
        let banner = R.nib.pinMessageBannerView(withOwner: nil)!
        banner.isHidden = true
        banner.delegate = self
        if let indicator = groupCallIndicatorViewIfLoaded {
            view.insertSubview(banner, belowSubview: indicator)
        } else {
            view.addSubview(banner)
        }
        banner.snp.makeConstraints { make in
            make.top.equalTo(navigationBarView.snp.bottom)
            make.left.right.equalTo(0)
            make.height.equalTo(pinMessageBannerHeight)
        }
        pinMessageBannerViewIfLoaded = banner
        return banner
    }()
    
    private var unreadBadgeValue: Int = 0 {
        didSet {
            guard unreadBadgeValue != oldValue else {
                return
            }
            unreadBadgeLabel.isHidden = unreadBadgeValue <= 0
            unreadBadgeLabel.text = unreadBadgeValue <= 99 ? String(unreadBadgeValue) : "99+"
        }
    }
    
    // Element is message_id
    private var mentionScrollingDestinations: [String] = [] {
        didSet {
            let wrapperAlpha: CGFloat
            if mentionScrollingDestinations.isEmpty {
                mentionWrapperHeightConstraint.constant = 5
                mentionCountLabel.isHidden = true
                wrapperAlpha = 0
            } else {
                mentionWrapperHeightConstraint.constant = 48
                mentionCountLabel.text = "\(mentionScrollingDestinations.count)"
                mentionCountLabel.isHidden = false
                wrapperAlpha = 1
            }
            UIView.animate(withDuration: 0.3) {
                self.mentionWrapperView.alpha = wrapperAlpha
                self.view.layoutIfNeeded()
            }
        }
    }
    
    private var isUserHandleHidden = true {
        didSet {
            if isUserHandleHidden {
                if userHandleViewController.isViewLoaded {
                    userHandleViewController.view.isHidden = true
                }
                inputWrapperTopShadowView.alpha = 0
            } else {
                loadUserHandleAsChildIfNeeded()
                userHandleViewController.view.isHidden = false
                inputWrapperTopShadowView.alpha = 1
            }
        }
    }
    
    private var maxInputWrapperHeight: CGFloat {
        return AppDelegate.current.mainWindow.frame.height
            - navigationBarView.frame.height
            - minInputWrapperTopMargin
    }
    
    private var groupCallIndicatorCenterYLimitation: (min: CGFloat, max: CGFloat) {
        let min: CGFloat
        if let banner = pinMessageBannerViewIfLoaded, !banner.isHidden {
            min = navigationBarView.frame.maxY + pinMessageBannerHeight + 33
        } else {
            min = AppDelegate.current.mainWindow.safeAreaInsets.top + titleViewHeightConstraint.constant + 30
        }
        let max = inputWrapperView.frame.minY - 30
        return (min, max)
    }
    
    deinit {
        AppGroupUserDefaults.User.currentConversationId = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Factory
    class func instance(conversation: ConversationItem, highlight: ConversationDataSource.Highlight? = nil) -> ConversationViewController {
        let vc = R.storyboard.chat.conversation()!
        let dataSource = ConversationDataSource(conversation: conversation, highlight: highlight)
        let ownerUser: UserItem?
        if dataSource.category == .contact {
            ownerUser = UserDAO.shared.getUser(userId: dataSource.conversation.ownerId)
        } else {
            ownerUser = nil
        }
        vc.ownerUser = ownerUser
        vc.dataSource = dataSource
        vc.composer = ConversationMessageComposer(dataSource: dataSource, ownerUser: ownerUser)
        return vc
    }
    
    class func instance(ownerUser: UserItem) -> ConversationViewController {
        let vc = R.storyboard.chat.conversation()!
        vc.ownerUser = ownerUser
        let conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: ownerUser.userId)
        let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId)
            ?? ConversationItem(ownerUser: ownerUser)
        let dataSource = ConversationDataSource(conversation: conversation)
        vc.dataSource = dataSource
        vc.composer = ConversationMessageComposer(dataSource: dataSource, ownerUser: ownerUser)
        return vc
    }
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        wallpaperImageView.snp.makeConstraints { (make) in
            make.height.equalTo(UIScreen.main.bounds.height)
        }
        wallpaperImageView.wallpaper = Wallpaper.wallpaper(for: .conversation(conversationId))
        tableView.snp.makeConstraints { (make) in
            make.height.equalTo(UIScreen.main.bounds.height)
        }
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
        
        reportRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(showReportMenuAction))
        reportRecognizer.minimumPressDuration = 2
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(reportRecognizer)
        
        fastReplyRecognizer = FastReplyGestureRecognizer(target: self, action: #selector(fastReplyAction(_:)))
        fastReplyRecognizer.delegate = self
        tableView.addGestureRecognizer(fastReplyRecognizer)
        
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapRecognizer.delegate = self
        tableView.addGestureRecognizer(tapRecognizer)
        
        textPreviewRecognizer = UITapGestureRecognizer(target: self, action: #selector(presentTextPreviewAction(_:)))
        textPreviewRecognizer.numberOfTapsRequired = 2
        textPreviewRecognizer.delegate = self
        tableView.addGestureRecognizer(textPreviewRecognizer)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        mentionCountLabel.contentInset = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
        unreadBadgeLabel.contentInset = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
        if dataSource.category == .group {
            let hasUnreadAnnouncement = AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] ?? false
            if hasUnreadAnnouncement {
                updateAnnouncementBadge(announcement: dataSource.conversation.announcement)
            } else {
                updateAnnouncementBadge(announcement: nil)
            }
        } else {
            showScamAnnouncementIfNeeded()
        }
        dataSource.ownerUser = ownerUser
        dataSource.tableView = tableView
        updateStrangerActionView()
        inputWrapperView.isHidden = false
        updateNavigationBar()
        updateNavigationBarHeightAndTableViewTopInset()
        conversationInputViewController = R.storyboard.chat.input()
        addChild(conversationInputViewController)
        inputWrapperView.addSubview(conversationInputViewController.view)
        conversationInputViewController.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        conversationInputViewController.didMove(toParent: self)
        if dataSource.category == .group {
            updateSubtitleAndInputBar()
            conversationInputViewController.detectsMentionToken = true
        } else if let user = ownerUser {
            conversationInputViewController.inputBarView.isHidden = false
            conversationInputViewController.update(opponentUser: user)
            conversationInputViewController.detectsMentionToken = user.isBot
        }
        AppGroupUserDefaults.User.currentConversationId = conversationId
        dataSource.initData(completion: finishInitialLoading)
        
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(conversationDidChange(_:)), name: MixinServices.conversationDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(usersDidChange(_:)), name: UserDAO.usersDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(participantDidChange(_:)), name: ParticipantDAO.participantDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(didAddMessageOutOfBounds(_:)), name: ConversationDataSource.newMessageOutOfVisibleBoundsNotification, object: dataSource)
        center.addObserver(self, selector: #selector(audioMessagePlayingManagerWillPlayNextNode(_:)), name: AudioMessagePlayingManager.willPlayNextNotification, object: AudioMessagePlayingManager.shared)
        center.addObserver(self, selector: #selector(willRecallMessage(_:)), name: SendMessageService.willRecallMessageNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        center.addObserver(self, selector: #selector(pinMessageDidSave(_:)), name: PinMessageDAO.didSaveNotification, object: nil)
        center.addObserver(self, selector: #selector(pinMessageDidDelete(_:)), name: PinMessageDAO.didDeleteNotification, object: nil)
        center.addObserver(self, selector: #selector(pinMessageBannerDidChange), name: AppGroupUserDefaults.User.pinMessageBannerDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(expiredMessageDidDelete(_:)), name: ExpiredMessageDAO.expiredMessageDidDeleteNotification, object: nil)
        center.addObserver(self, selector: #selector(wallpaperDidChange), name: Wallpaper.wallpaperDidChangeNotification, object: nil)
        
        if dataSource.category == .group {
            updateGroupCallIndicatorViewHidden()
            CallService.shared.membersManager.loadMembersAsynchornously(forConversationWith: conversationId)
            center.addObserver(self,
                               selector: #selector(updateGroupCallIndicatorViewHidden),
                               name: GroupCallMembersManager.membersDidChangeNotification,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(updateGroupCallIndicatorViewHidden),
                               name: CallService.didActivateCallNotification,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(updateGroupCallIndicatorViewHidden),
                               name: CallService.didDeactivateCallNotification,
                               object: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isAppearanceAnimating = true
        if makeInputTextViewFirstResponderOnAppear {
            conversationInputViewController.textView.becomeFirstResponder()
            makeInputTextViewFirstResponderOnAppear = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isAppearanceAnimating = false
        if let user = self.ownerUser {
            let job = RefreshUserJob(userIds: [user.userId])
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if conversationInputViewController.textView.isFirstResponder {
            makeInputTextViewFirstResponderOnAppear = true
        }
        super.viewWillDisappear(animated)
        isAppearanceAnimating = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AudioMessagePlayingManager.shared.stop()
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            if let lastIndexPath = dataSource?.lastIndexPath, visibleIndexPaths.contains(lastIndexPath), tableView.rectForRow(at: lastIndexPath).origin.y < tableView.contentOffset.y + tableView.frame.height - tableView.contentInset.bottom {
                ConversationViewController.positions[conversationId] = nil
            } else {
                for indexPath in visibleIndexPaths {
                    guard let message = dataSource?.viewModel(for: indexPath)?.message, message.category != MessageCategory.EXT_UNREAD.rawValue else {
                        continue
                    }
                    let rect = tableView.rectForRow(at: indexPath)
                    let offset = tableView.contentInset.top + tableView.contentOffset.y - rect.origin.y
                    let position = Position(messageId: message.messageId, offset: offset)
                    ConversationViewController.positions[conversationId] = position
                    break
                }
            }
        }
        if parent == nil {
            dataSource?.cancelMessageProcessing()
        }
        SendMessageService.shared.sendReadMessages(conversationId: conversationId)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateNavigationBarHeightAndTableViewTopInset()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previous = previousTraitCollection, traitCollection.preferredContentSizeCategory != previous.preferredContentSizeCategory else {
            return
        }
        let messageId: String?
        if let indexPath = dataSource.focusIndexPath {
            messageId = dataSource.viewModel(for: indexPath)?.message.messageId
        } else {
            messageId = nil
        }
        dataSource.reload(initialMessageId: messageId)
    }
    
    // MARK: - Actions
    @IBAction func profileAction(_ sender: Any) {
        if let dataSource = dataSource, dataSource.category == .group {
            let vc = GroupProfileViewController(conversation: dataSource.conversation,
                                                numberOfParticipants: numberOfParticipants,
                                                isMember: isMember)
            present(vc, animated: true, completion: nil)
        } else if let user = ownerUser {
            let vc = UserProfileViewController(user: user)
            present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func scrollToBottomAction(_ sender: Any) {
        unreadBadgeValue = 0
        if let quotingMessageId = quotingMessageId, let indexPath = dataSource?.indexPath(where: { $0.messageId == quotingMessageId }) {
            self.quotingMessageId = nil
            scheduleCellBackgroundFlash(messageId: quotingMessageId)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        } else if let quotingMessageId = quotingMessageId, MessageDAO.shared.hasMessage(id: quotingMessageId) {
            self.quotingMessageId = nil
            messageIdToFlashAfterAnimationFinished = quotingMessageId
            reloadWithMessageId(quotingMessageId, scrollUpwards: true)
        } else {
            dataSource?.scrollToFirstUnreadMessageOrBottom()
        }
    }
    
    @IBAction func scrollToMentionAction(_ sender: Any) {
        guard let id = mentionScrollingDestinations.first else {
            return
        }
        if let indexPath = dataSource?.indexPath(where: { $0.messageId == id }) {
            mentionScrollingDestinations.removeFirst()
            scheduleCellBackgroundFlash(messageId: id)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        } else if MessageDAO.shared.hasMessage(id: id) {
            mentionScrollingDestinations.removeFirst()
            messageIdToFlashAfterAnimationFinished = id
            reloadWithMessageId(id, scrollUpwards: true)
        }
    }
    
    @IBAction func multipleSelectionAction(_ sender: Any) {
        switch multipleSelectionActionView.intent {
        case .forward:
            let messages = dataSource.selectedViewModels.values
                .map({ $0.message })
                .sorted(by: { $0.createdAt < $1.createdAt })
            let containsTranscriptMessage = messages.contains {
                $0.category.hasSuffix("_TRANSCRIPT")
            }
            if messages.count == 1 || containsTranscriptMessage {
                let vc = MessageReceiverViewController.instance(content: .messages(messages))
                navigationController?.pushViewController(vc, animated: true)
            } else {
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: R.string.localizable.one_by_one_forward(), style: .default, handler: { (_) in
                    let vc = MessageReceiverViewController.instance(content: .messages(messages))
                    self.navigationController?.pushViewController(vc, animated: true)
                }))
                alert.addAction(UIAlertAction(title: R.string.localizable.combine_and_forward(), style: .default, handler: { (_) in
                    let vc = MessageReceiverViewController.instance(content: .transcript(messages))
                    self.navigationController?.pushViewController(vc, animated: true)
                }))
                alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        case .delete:
            let viewModels = dataSource.selectedViewModels.values.map({ $0 })
            let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if !viewModels.contains(where: { $0.message.userId != myUserId || !$0.message.canRecall }) {
                controller.addAction(UIAlertAction(title: R.string.localizable.delete_for_everyone(), style: .destructive, handler: { (_) in
                    if AppGroupUserDefaults.User.hasShownRecallTips {
                        self.deleteForEveryone(viewModels: viewModels)
                    } else {
                        self.showRecallTips(viewModels: viewModels)
                    }
                }))
            }
            controller.addAction(UIAlertAction(title: R.string.localizable.delete_for_me(), style: .destructive, handler: { (_) in
                self.deleteForMe(viewModels: viewModels)
            }))
            controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    @IBAction func dismissAnnouncementBadgeAction(_ sender: Any) {
        if dataSource.category == .group {
            AppGroupUserDefaults.User.hasUnreadAnnouncement.removeValue(forKey: conversationId)
        } else if let user = self.ownerUser {
            AppGroupUserDefaults.User.closeScamAnnouncementDate[user.userId] = Date()
        }
        updateAnnouncementBadge(announcement: nil)
    }
    
    @IBAction func groupCallIndicatorPanAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: nil)
        case .changed:
            groupCallIndicatorCenterYConstraint?.constant += recognizer.translation(in: nil).y
            recognizer.setTranslation(.zero, in: nil)
        case .ended:
            layoutGroupCallIndicatorView()
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           options: .curveEaseOut,
                           animations: view.layoutIfNeeded,
                           completion: nil)
        default:
            break
        }
    }
    
    @IBAction func joinGroupCallAction(_ sender: Any) {
        startOrJoinGroupCall()
    }
    
    @objc func resizeInputWrapperAction(_ recognizer: ResizeInputWrapperGestureRecognizer) {
        let location = if #available(iOS 26, *) {
            recognizer.location(in: conversationInputViewController.customInputContainerView)
        } else {
            recognizer.location(in: inputWrapperView)
        }
        let verticalVelocity = recognizer.velocity(in: view).y
        let regularInputWrapperHeight = conversationInputViewController.regularHeight
        var inputWrapperHeight: CGFloat {
            get {
                return inputWrapperHeightConstraint.constant
            }
            set {
                inputWrapperHeightConstraint.constant = newValue
            }
        }
        switch recognizer.state {
        case .began:
            recognizer.inputWrapperHeightWhenBegan = inputWrapperHeight
        case .changed:
            if !tableView.isScrollEnabled {
                // Prevent input wrapper get resized when fast reply gesture is working
                return
            }
            let shouldMoveDown = verticalVelocity > 0 && location.y > 0
            let canMoveUp = !conversationInputViewController.textView.isFirstResponder
                || inputWrapperHeight < conversationInputViewController.regularHeight
            let shouldMoveUp = canMoveUp
                && location.y < 0
                && verticalVelocity < 0
                && recognizer.hasMovedInputWrapperDuringChangedState
            if shouldMoveDown || shouldMoveUp {
                recognizer.hasMovedInputWrapperDuringChangedState = true
                var newHeight = inputWrapperHeight - recognizer.translation(in: view).y
                if newHeight < conversationInputViewController.minimizedHeight {
                    newHeight = conversationInputViewController.minimizedHeight
                    if shouldMoveDown && conversationInputViewController.view.backgroundColor == .clear {
                        conversationInputViewController.view.backgroundColor = .background
                    }
                }
                if conversationInputViewController.isMaximizable {
                    newHeight = min(newHeight, maxInputWrapperHeight)
                } else {
                    newHeight = min(newHeight, regularInputWrapperHeight)
                }
                updateNavigationBarPositionWithInputWrapperViewHeight(oldHeight: inputWrapperHeight, newHeight: newHeight)
                inputWrapperHeight = newHeight
                view.layoutIfNeeded()
            }
            recognizer.setTranslation(.zero, in: view)
        case .ended:
            let shouldResize = abs(inputWrapperHeight - recognizer.inputWrapperHeightWhenBegan) > 1
                && !conversationInputViewController.textView.isFirstResponder
            if shouldResize {
                if verticalVelocity >= 0 {
                    if inputWrapperHeight > regularInputWrapperHeight {
                        conversationInputViewController.setPreferredContentHeightAnimated(.regular)
                    } else {
                        conversationInputViewController.dismissCustomInput(minimize: true)
                    }
                } else {
                    if inputWrapperHeight > conversationInputViewController.regularHeight {
                        conversationInputViewController.setPreferredContentHeightAnimated(.maximized)
                    } else {
                        conversationInputViewController.setPreferredContentHeightAnimated(.regular)
                    }
                }
            }
        default:
            break
        }
    }
    
    @objc func blockAction(_ sender: Any) {
        guard let userId = ownerUser?.userId else {
            return
        }
        strangerHintView.blockButton.isBusy = true
        UserAPI.blockUser(userId: userId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerHintView.blockButton.isBusy = false
            switch result {
            case .success(let userResponse):
                UserDAO.shared.updateUsers(users: [userResponse])
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc func addContactAction(_ sender: Any) {
        guard let user = ownerUser else {
            return
        }
        strangerHintView.addContactButton.isBusy = true
        UserAPI.addFriend(userId: user.userId, fullName: user.fullName) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerHintView.addContactButton.isBusy = false
            switch result {
            case .success(let userResponse):
                UserDAO.shared.updateUsers(users: [userResponse])
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc func exitGroupAndReportInviterAction(_ sender: Any) {
        guard let inviterId = myInvitation?.userId else {
            return
        }
        let conversationId = self.conversationId
        let alert = UIAlertController(title: R.string.localizable.exit_group_and_report_inviter(), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.confirm(), style: .destructive, handler: { _ in
            let hud = Hud()
            if let view = self.navigationController?.view {
                hud.show(style: .busy, text: "", on: view)
            }
            UserAPI.reportUser(userId: inviterId) { result in
                switch result {
                case let .success(user):
                    DispatchQueue.global().async {
                        UserDAO.shared.updateUsers(users: [user])
                    }
                    ConversationAPI.exitConversation(conversationId: conversationId) { result in
                        let exitGroup = {
                            DispatchQueue.global().async {
                                ConversationDAO.shared.exitGroup(conversationId: conversationId)
                            }
                            hud.set(style: .notification, text: R.string.localizable.done())
                        }
                        switch result {
                        case .success:
                            exitGroup()
                        case let .failure(error):
                            switch error {
                            case .forbidden, .notFound:
                                exitGroup()
                            default:
                                hud.set(style: .error, text: error.localizedDescription)
                            }
                        }
                        hud.scheduleAutoHidden()
                    }
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func greetAppAction(_ sender: Any) {
        tableView.tableFooterView = nil
        composer.sendMessage(type: .SIGNAL_TEXT, value: "Hi")
    }
    
    @objc func tapAction(_ recognizer: UIGestureRecognizer) {
        if conversationInputViewController.audioViewController.hideLongPressHint() {
            return
        }
        let tappedIndexPath = tableView.indexPathForRow(at: recognizer.location(in: tableView))
        let tappedViewModel: MessageViewModel? = {
            if let indexPath = tappedIndexPath {
                return dataSource?.viewModel(for: indexPath)
            } else {
                return nil
            }
        }()
        if tableView.allowsMultipleSelection {
            if let indexPath = tappedIndexPath, let viewModel = tappedViewModel {
                if let indexPaths = tableView.indexPathsForSelectedRows, indexPaths.contains(indexPath) {
                    tableView.deselectRow(at: indexPath, animated: true)
                    dataSource.selectedViewModels[viewModel.message.messageId] = nil
                } else {
                    let availability = self.viewModel(viewModel, availabilityForMultipleSelectionWith: multipleSelectionActionView.intent)
                    switch availability {
                    case .available:
                        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                        dataSource.selectedViewModels[viewModel.message.messageId] = viewModel
                    case let .visibleButUnavailable(reason):
                        presentGotItAlertController(title: reason)
                    case .invisible:
                        break
                    }
                }
            }
            multipleSelectionActionView.numberOfSelection = dataSource.selectedViewModels.count
            return
        }
        if let indexPath = tappedIndexPath, let cell = tableView.cellForRow(at: indexPath) as? MessageCell, cell.contentFrame.contains(recognizer.location(in: cell)), let viewModel = tappedViewModel {
            let message = viewModel.message
            let isImageOrVideo = message.category.hasSuffix("_IMAGE") || message.category.hasSuffix("_VIDEO")
            let mediaStatusIsReady = message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue
            if let quoteMessageId = viewModel.message.quoteMessageId, !quoteMessageId.isEmpty, let quote = cell.quotedMessageViewIfLoaded, quote.bounds.contains(recognizer.location(in: quote)) {
                if let indexPath = dataSource?.indexPath(where: { $0.messageId == quoteMessageId }) {
                    quotingMessageId = message.messageId
                    scheduleCellBackgroundFlash(messageId: quoteMessageId)
                    tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                } else if MessageDAO.shared.hasMessage(id: quoteMessageId) {
                    quotingMessageId = message.messageId
                    messageIdToFlashAfterAnimationFinished = quoteMessageId
                    reloadWithMessageId(quoteMessageId, scrollUpwards: false)
                }
            } else if message.category.hasSuffix("_AUDIO"), message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue {
                if AudioMessagePlayingManager.shared.playingMessage?.messageId == message.messageId, AudioMessagePlayingManager.shared.player?.status == .playing {
                    AudioMessagePlayingManager.shared.pause()
                } else if CallService.shared.hasCall {
                    alert(R.string.localizable.call_on_another_call_hint())
                } else {
                    (cell as? AudioMessageCell)?.updateUnreadStyle()
                    AudioMessagePlayingManager.shared.play(message: message)
                }
            } else if (isImageOrVideo && mediaStatusIsReady) || message.category.hasSuffix("_LIVE"), let item = GalleryItem(message: message), let cell = cell as? PhotoRepresentableMessageCell {
                adjustTableViewContentOffsetWhenInputWrapperHeightChanges = false
                conversationInputViewController.dismiss()
                adjustTableViewContentOffsetWhenInputWrapperHeightChanges = true
                if let galleryViewController = UIApplication.homeContainerViewController?.galleryViewController {
                    galleryViewController.conversationId = conversationId
                    galleryViewController.show(item: item, from: cell)
                }
            } else if message.category.hasSuffix("_DATA"), let viewModel = viewModel as? DataMessageViewModel, let cell = cell as? DataMessageCell {
                if viewModel.mediaStatus == MediaStatus.DONE.rawValue || viewModel.mediaStatus == MediaStatus.READ.rawValue {
                    conversationInputViewController.dismiss()
                    UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                    if viewModel.isListPlayable {
                        if CallService.shared.hasCall {
                            alert(R.string.localizable.call_on_another_call_hint())
                        } else {
                            let item = PlaylistItem(message: message)
                            PlaylistManager.shared.playOrPause(index: 0, in: [item], source: .conversation(message.conversationId))
                        }
                    } else {
                        openDocumentAction(message: message)
                    }
                } else {
                    attachmentLoadingCellDidSelectNetworkOperation(cell)
                }
            } else if message.category.hasSuffix("_CONTACT"), let shareUserId = message.sharedUserId {
                conversationInputViewController.dismiss()
                if shareUserId == myUserId {
                    guard let account = LoginManager.shared.account else {
                        return
                    }
                    let user = UserItem.createUser(from: account)
                    let vc = UserProfileViewController(user: user)
                    present(vc, animated: true, completion: nil)
                } else if let user = UserDAO.shared.getUser(userId: shareUserId) {
                    let vc = UserProfileViewController(user: user)
                    present(vc, animated: true, completion: nil)
                }
            } else if message.category.hasSuffix("_POST") {
                let message = Message.createMessage(message: message)
                PostWebViewController.presentInstance(message: message, asChildOf: self)
            } else if message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
                conversationInputViewController.dismiss()
                open(url: .aboutEncryption)
            } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                conversationInputViewController.dismiss()
                DispatchQueue.global().async { [weak self] in
                    guard let assetId = message.snapshotAssetId, let snapshotId = message.snapshotId, let asset = AssetDAO.shared.getAsset(assetId: assetId), let snapshot = SnapshotDAO.shared.getSnapshot(snapshotId: snapshotId) else {
                        return
                    }
                    DispatchQueue.main.async {
                        self?.navigationController?.pushViewController(LegacyTransactionViewController.instance(asset: asset, snapshot: snapshot), animated: true)
                    }
                }
            } else if message.category == MessageCategory.SYSTEM_SAFE_SNAPSHOT.rawValue || message.category == MessageCategory.SYSTEM_SAFE_INSCRIPTION.rawValue {
                conversationInputViewController.dismiss()
                DispatchQueue.global().async { [weak self] in
                    guard
                        let assetId = message.snapshotAssetId,
                        let snapshotId = message.snapshotId,
                        let snapshot = SafeSnapshotDAO.shared.snapshotItem(id: snapshotId),
                        let token = TokenDAO.shared.tokenItem(assetID: assetId)
                    else {
                        return
                    }
                    DispatchQueue.main.async {
                        let viewController = SafeSnapshotViewController(
                            token: token,
                            snapshot: snapshot,
                            messageID: message.messageId,
                            inscription: message.inscription
                        )
                        self?.navigationController?.pushViewController(viewController, animated: true)
                        reporter.report(event: .transactionDetail, tags: ["source": "chat"])
                    }
                }
            } else if message.category == MessageCategory.APP_CARD.rawValue, let appCard = message.appCard {
                conversationInputViewController.dismiss()
                openAppCard(appCard: appCard, sendUserId: message.userId)
            } else if message.category.hasSuffix("_LOCATION"), let location = message.location {
                let vc = LocationPreviewViewController(location: location)
                navigationController?.pushViewController(vc, animated: true)
            } else if message.category.hasSuffix("_TRANSCRIPT") {
                let vc = TranscriptPreviewViewController(transcriptMessage: message)
                vc.presentAsChild(of: self)
            } else if message.category.hasSuffix("_STICKER") {
                conversationInputViewController.dismiss()
                let vc = StickerPreviewViewController.instance(message: message)
                vc.presentAsChild(of: self)
            } else {
                conversationInputViewController.dismiss()
            }
        } else {
            conversationInputViewController.dismiss()
        }
    }
    
    @objc func fastReplyAction(_ recognizer: FastReplyGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let location = recognizer.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: location) {
                recognizer.cell = tableView.cellForRow(at: indexPath) as? MessageCell
            }
            recognizer.setTranslation(.zero, in: recognizer.view)
            tableView.isScrollEnabled = false
            feedback.prepare()
        case .changed:
            guard let cell = recognizer.cell else {
                return
            }
            let oldX = cell.messageContentView.frame.origin.x
            var newX = oldX + recognizer.translation(in: recognizer.view).x
            newX = min(0, max(-fastReplyMaxDistance, newX))
            if oldX > -fastReplyConfirmedDistance && newX <= -fastReplyConfirmedDistance {
                feedback.impactOccurred()
            }
            cell.messageContentView.frame.origin.x = newX
            recognizer.setTranslation(.zero, in: recognizer.view)
        case .ended:
            tableView.isScrollEnabled = true
            guard let cell = recognizer.cell else {
                return
            }
            let shouldQuote = cell.messageContentView.frame.origin.x <= -fastReplyConfirmedDistance
            UIView.animate(withDuration: animationDuration) {
                cell.messageContentView.frame.origin.x = 0
            }
            if shouldQuote, let viewModel = cell.viewModel {
                conversationInputViewController.quote = (viewModel.message, viewModel.thumbnail)
            }
        case .cancelled, .failed:
            tableView.isScrollEnabled = true
        default:
            break
        }
    }
    
    @objc func presentTextPreviewAction(_ recognizer: UITapGestureRecognizer) {
        guard let cell = tableView.messageCellForRow(at: recognizer.location(in: tableView)) else {
            return
        }
        guard type(of: cell) == TextMessageCell.self else {
            return
        }
        guard let viewModel = cell.viewModel as? TextMessageViewModel else {
            return
        }
        guard cell.contentFrame.contains(recognizer.location(in: cell)) else {
            return
        }
        guard !(tableView.isDragging && tableView.isDecelerating) else {
            return
        }
        let textPreviewView = R.nib.textPreviewView(withOwner: nil)!
        textPreviewView.attributedText = viewModel.contentAttributedString
        textPreviewView.show(on: view)
    }
    
    @objc func showReportMenuAction() {
        guard !self.conversationId.isEmpty else {
            return
        }
        
        let conversationId = self.conversationId
        let alc = UIAlertController(title: R.string.localizable.report_title(), message: MixinHost.http, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: R.string.localizable.send_to_developer(), style: .default, handler: { (_) in
            self.report(conversationId: conversationId)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.share_log_file(), style: .default, handler: { (_) in
            self.reportAirDop(conversationId: conversationId)
        }))
        if !Self.allowReportSingleMessage {
            alc.addAction(UIAlertAction(title: R.string.localizable.allow_manual_report_message(), style: .default, handler: { (_) in
                Self.allowReportSingleMessage = true
            }))
        }
        
        if myIdentityNumber == "762532" || myIdentityNumber == "26596" {
            if let userId = ownerUser?.userId, dataSource.category == .contact {
                alc.addAction(UIAlertAction(title: R.string.localizable.copy_user_id(), style: .default, handler: {(_) in
                    UIPasteboard.general.string = userId
                }))
            }
            alc.addAction(UIAlertAction(title: R.string.localizable.copy_conversation_id(), style: .default, handler: { (_) in
                UIPasteboard.general.string = self.conversationId
            }))
        }
        
        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    @objc private func buyOpponentMembership(_ sender: Any) {
        guard let plan = ownerUser?.membership?.unexpiredPlan else {
            return
        }
        let buyingPlan = SafeMembership.Plan(userMembershipPlan: plan)
        let plans = MembershipPlansViewController(selectedPlan: buyingPlan)
        present(plans, animated: true)
    }
    
    // MARK: - Callbacks
    @objc func conversationDidChange(_ sender: Notification) {
        guard let change = sender.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case let .updateGroupIcon(iconUrl):
            avatarImageView?.setGroupImage(with: iconUrl)
        case .update:
            hideLoading()
        case let .updateConversation(conversation):
            if !conversation.name.isEmpty {
                titleLabel.text = conversation.name
                dataSource?.conversation.name = conversation.name
            }
            if let dataSource = dataSource, dataSource.category == .group {
                dataSource.conversation.announcement = conversation.announcement
                let hasUnreadAnnouncement = AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] ?? false
                let canShowAnnouncement = ScreenHeight.current > .short || !isShowingKeyboard
                if hasUnreadAnnouncement && canShowAnnouncement {
                    updateAnnouncementBadge(announcement: conversation.announcement)
                } else {
                    updateAnnouncementBadge(announcement: nil)
                }
            }
            hideLoading()
        case .startedUpdateConversation:
            showLoading()
        case let .updateMessageMentionStatus(messageId, newStatus):
            if newStatus == .MENTION_READ {
                mentionScrollingDestinations.removeAll(where: { $0 == messageId })
            }
        case let .updateConversationStatus(status) where status == .QUIT:
            updateInvitationHintView()
        default:
            break
        }
    }
    
    @objc func usersDidChange(_ notification: Notification) {
        guard
            let userResponses = notification.userInfo?[UserDAO.UserInfoKey.users] as? [UserResponse],
            userResponses.count == 1,
            userResponses[0].userId == ownerUser?.userId
        else {
            return
        }
        let user = UserItem.createUser(from: userResponses[0])
        ownerUser = user
        updateNavigationBar()
        conversationInputViewController.update(opponentUser: user)
        updateStrangerActionView()
        hideLoading()
        dataSource?.ownerUser = user
        updateInvitationHintView()
        showScamAnnouncementIfNeeded()
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[ParticipantDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard isViewLoaded, conversationId == self.conversationId else {
            return
        }
        updateSubtitleAndInputBar()
        dataSource.queue.async { [weak self] in
            let users = ParticipantDAO.shared.getParticipants(conversationId: conversationId)
            DispatchQueue.main.sync {
                self?.userHandleViewController.users = users
            }
            self?.updateMessagePinningAvailability()
        }
    }
    
    @objc func didAddMessageOutOfBounds(_ notification: Notification) {
        if let count = notification.userInfo?[ConversationDataSource.UserInfoKey.unreadMessageCount] as? Int {
            unreadBadgeValue += count
        }
        if let ids = notification.userInfo?[ConversationDataSource.UserInfoKey.mentionedMessageIds] as? [String] {
            mentionScrollingDestinations.append(contentsOf: ids)
        }
    }
    
    @objc func audioMessagePlayingManagerWillPlayNextNode(_ notification: Notification) {
        guard !tableView.isTracking else {
            return
        }
        guard let conversationId = notification.userInfo?[AudioMessagePlayingManager.conversationIdUserInfoKey] as? String, conversationId == dataSource.conversationId else {
            return
        }
        guard let messageId = notification.userInfo?[AudioMessagePlayingManager.messageIdUserInfoKey] as? String else {
            return
        }
        if let indexPath = dataSource.indexPath(where: { $0.messageId == messageId }) {
            let cellFrame = tableView.convert(tableView.rectForRow(at: indexPath), to: view)
            let isCellInvisible = cellFrame.minY < navigationBarView.frame.height
                || cellFrame.maxY > view.bounds.height - inputWrapperView.frame.height
            if isCellInvisible {
                tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
            }
        } else {
            dataSource.scrollToBottomAndReload(initialMessageId: messageId, completion: nil)
        }
    }
    
    @objc func willRecallMessage(_ notification: Notification) {
        guard let messageId = notification.userInfo?[SendMessageService.UserInfoKey.messageId] as? String, messageId == previewDocumentMessageId else {
            return
        }
        previewDocumentController?.dismissPreview(animated: true)
        previewDocumentController?.dismissMenu(animated: true)
        previewDocumentController = nil
        previewDocumentMessageId = nil
    }
    
    @objc func endMultipleSelection() {
        dataSource.selectedViewModels.removeAll()
        for cell in tableView.visibleCells.compactMap({ $0 as? MessageCell }) {
            cell.setMultipleSelecting(false, animated: true)
        }
        tableView.indexPathsForSelectedRows?.forEach({ (indexPath) in
            tableView.deselectRow(at: indexPath, animated: true)
        })
        tableView.allowsMultipleSelection = false
        cancelSelectionButton.removeFromSuperview()
        
        showInputWrapperConstraint.priority = .defaultHigh
        hideInputWrapperConstraint.priority = .defaultLow
        UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                let old = self.multipleSelectionActionView.frame.height
                let new = self.inputWrapperHeightConstraint.constant
                self.updateTableViewBottomInsetWithBottomBarHeight(old: old, new: new, animated: false)
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                self.multipleSelectionActionView.frame.origin.y = self.view.bounds.height
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }, completion: { _ in
            self.multipleSelectionActionView.removeFromSuperview()
        })
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        isShowingKeyboard = true
        if ScreenHeight.current <= .short {
            updateAnnouncementBadge(announcement: nil)
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        isShowingKeyboard = false
        if dataSource.category == .group {
            let hasUnreadAnnouncement = AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] ?? false
            if ScreenHeight.current <= .short && hasUnreadAnnouncement {
                updateAnnouncementBadge(announcement: dataSource.conversation.announcement)
            }
        } else {
            if ScreenHeight.current <= .short {
                showScamAnnouncementIfNeeded()
            }
        }
    }
    
    @objc private func pinMessageDidSave(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[PinMessageDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        dataSource.queue.async { [weak self] in
            guard
                let messageId = notification.userInfo?[PinMessageDAO.UserInfoKey.messageId] as? String,
                let message = MessageDAO.shared.getFullMessage(messageId: messageId),
                let referencedMessageId = notification.userInfo?[PinMessageDAO.UserInfoKey.referencedMessageId] as? String
            else {
                return
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.pinnedMessageIds.insert(referencedMessageId)
                self.pinMessageBannerView.isHidden = false
                self.updatePinMessagePreview(item: message)
                self.layoutGroupCallIndicatorView()
            }
        }
    }
    
    @objc private func pinMessageDidDelete(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[PinMessageDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        dataSource.queue.async { [weak self] in
            let hasMessage = PinMessageDAO.shared.hasMessage(conversationId: conversationId)
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                if let referencedMessageIds = notification.userInfo?[PinMessageDAO.UserInfoKey.referencedMessageIds] as? [String] {
                    self.pinnedMessageIds.subtract(referencedMessageIds)
                } else {
                    self.pinnedMessageIds = []
                }
                if !hasMessage {
                    self.pinMessageBannerViewIfLoaded?.isHidden = true
                }
            }
        }
    }
    
    @objc private func pinMessageBannerDidChange() {
        if AppGroupUserDefaults.User.pinMessageBanners[conversationId] == nil {
            hidePinMessagePreview()
        }
    }
    
    @objc private func expiredMessageDidDelete(_ notification: Notification) {
        guard let messageId = notification.userInfo?[ExpiredMessageDAO.messageIdKey] as? String else {
            return
        }
        guard let indexPath = dataSource.indexPath(where: { $0.messageId == messageId }) else {
            return
        }
        _ = dataSource?.removeViewModel(at: indexPath)
        tableView.reloadData()
    }
    
    @objc private func wallpaperDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[Wallpaper.conversationIdUserInfoKey] as? String, conversationId == self.conversationId else {
            return
        }
        wallpaperImageView.wallpaper = Wallpaper.wallpaper(for: .conversation(conversationId))
    }
    
    // MARK: - Interface
    func updateInputWrapper(for preferredContentHeight: CGFloat, animated: Bool) {
        let oldHeight = inputWrapperHeightConstraint.constant
        let newHeight = min(maxInputWrapperHeight, preferredContentHeight)
        let adjustInputWrapperHeight = {
            self.inputWrapperHeightConstraint.constant = newHeight
        }
        if animated {
            adjustInputWrapperHeight()
        } else {
            UIView.performWithoutAnimation(adjustInputWrapperHeight)
        }
        updateTableViewBottomInsetWithBottomBarHeight(old: oldHeight, new: newHeight, animated: animated)
    }
    
    func inputTextViewDidInputMentionCandidate(_ keyword: String?) {
        if let ownerUser = ownerUser, ownerUser.isBot {
            self.lastMentionCandidate = keyword
            let conversationId = conversationId
            DispatchQueue.global().async { [weak self] in
                let users: [UserItem]
                if let keyword = keyword, !keyword.isEmpty {
                    let oneWeekAgo = Date().addingTimeInterval(-7 * TimeInterval.day).toUTCString()
                    users = UserDAO.shared.botGroupUsers(conversationId: conversationId, keyword: keyword, createAt: oneWeekAgo)
                } else {
                    users = UserDAO.shared.contacts(count: 20)
                }
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    guard keyword == self.lastMentionCandidate else {
                        return
                    }
                    self.userHandleViewController.users = users
                    self.userHandleViewController.reload(with: keyword) { (hasContent) in
                        self.isUserHandleHidden = !hasContent
                    }
                }
            }
        } else {
            userHandleViewController.reload(with: keyword) { (hasContent) in
                self.isUserHandleHidden = !hasContent
            }
        }
    }
    
    func inputUserHandle(with user: UserItem) {
        conversationInputViewController.textView.replaceInputingMentionToken(with: user)
    }
    
    func presentCamera() {
        VideoCaptureDevice.checkAuthorization {
            let picker = UIImagePickerController()
            picker.mediaTypes = [UTType.image.identifier]
            picker.delegate = self
            picker.modalPresentationStyle = .overFullScreen
            picker.sourceType = .camera
            self.present(picker, animated: true)
        } onDenied: { alert in
            self.present(alert, animated: true)
        }
    }
    
    func presentDocumentPicker() {
        let vc = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .import)
        vc.delegate = self
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true, completion: nil)
    }
    
    func showTransfer() {
        guard let ownerUser else {
            return
        }
        reporter.report(event: .sendStart, tags: ["wallet": "main", "source": "chat"])
        let selector = MixinTokenSelectorViewController(intent: .send)
        selector.onSelected = { (token, location) in
            reporter.report(event: .sendTokenSelect, tags: ["method": location.asEventMethod])
            reporter.report(event: .sendRecipient, tags: ["type": "contact"])
            let inputAmount = TransferInputAmountViewController(
                tokenItem: token,
                receiver: .user(ownerUser)
            )
            self.navigationController?.pushViewController(inputAmount, animated: true)
        }
        present(selector, animated: true)
    }
    
    func showLocationPicker() {
        let vc = LocationPickerViewController(input: conversationInputViewController)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func showContactSelector() {
        let vc = ContactSelectorViewController.instance(conversationInputViewController: conversationInputViewController)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func callOwnerUserIfPresent() {
        guard let ownerUser = dataSource.ownerUser else {
            return
        }
        CallService.shared.makePeerCall(with: ownerUser)
    }
    
    func openOpponentApp(_ app: App) {
        guard !conversationId.isEmpty else {
            return
        }
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        container.presentWebViewController(context: .init(conversationId: conversationId, app: app))
    }
    
    func startOrJoinGroupCall() {
        guard dataSource.category == .group else {
            return
        }
        guard WebSocketService.shared.isConnected else {
            CallService.shared.alert(error: CallError.networkFailure)
            return
        }
        
        let conversation = dataSource.conversation
        let conversationId = conversation.conversationId
        let service = CallService.shared
        
        AVAudioSession.sharedInstance().requestRecordPermission { (isGranted) in
            DispatchQueue.main.async {
                guard isGranted else {
                    CallService.shared.alert(error: CallError.microphonePermissionDenied)
                    return
                }
                let activeCall = service.activeCall
                if service.isInterfaceMinimized, activeCall?.conversationId == conversationId {
                    service.setInterfaceMinimized(false, animated: true)
                } else if activeCall != nil {
                    service.alert(error: CallError.busy)
                } else {
                    let inCallIds = service.membersManager.memberIds(forConversationWith: conversationId)
                    if !inCallIds.isEmpty {
                        service.showJoinGroupCallConfirmation(conversation: conversation, memberIds: inCallIds)
                    } else {
                        let picker = GroupCallMemberPickerViewController(conversation: conversation)
                        picker.appearance = .startNewCall
                        picker.onConfirmation = { (members) in
                            service.makeGroupCall(conversation: conversation, invitees: members)
                        }
                        self.present(picker, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func scrollToMessage(messageId: String) {
        if let indexPath = dataSource.indexPath(where: { $0.messageId == messageId }) {
            scheduleCellBackgroundFlash(messageId: messageId)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        } else if MessageDAO.shared.hasMessage(id: messageId) {
            messageIdToFlashAfterAnimationFinished = messageId
            reloadWithMessageId(messageId, scrollUpwards: true)
        }
    }
    
}

// MARK: - HomeNavigationController.NavigationBarStyling
extension ConversationViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .hide
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension ConversationViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        switch gestureRecognizer {
        case resizeInputRecognizer:
            return tableView.isScrollEnabled
                && inputWrapperHeightConstraint.constant > conversationInputViewController.minimizedHeight
        case fastReplyRecognizer:
            guard !tableView.allowsMultipleSelection else {
                return false
            }
            guard let indexPath = tableView.indexPathForRow(at: gestureRecognizer.location(in: tableView)) else {
                return false
            }
            guard let cell = tableView.cellForRow(at: indexPath) as? MessageCell else {
                return false
            }
            guard let viewModel = cell.viewModel, availableActions(for: viewModel.message).contains(.reply) else {
                return false
            }
            let velocity = fastReplyRecognizer.velocity(in: nil)
            return velocity.x < 0 && abs(velocity.x) > abs(velocity.y) * 2
        case textPreviewRecognizer:
            return !tableView.allowsMultipleSelection
        default:
            return true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        switch gestureRecognizer {
        case tapRecognizer:
            if let view = touch.view as? CoreTextLabel {
                return !view.canResponseTouch(at: touch.location(in: view))
            } else {
                return true
            }
        default:
            return true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return !(gestureRecognizer == tapRecognizer || otherGestureRecognizer == tapRecognizer)
    }
    
}

// MARK: - UITableViewDataSource
extension ConversationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource?.viewModels(for: section)?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return self.tableView.dequeueReusableCell(withReuseId: .unknown, for: indexPath)
        }
        let cell = self.tableView.dequeueReusableCell(withMessage: viewModel.message, for: indexPath)
        if let cell = cell as? DetailInfoMessageCell {
            cell.delegate = self
        }
        if let cell = cell as? AttachmentLoadingMessageCell {
            cell.attachmentLoadingDelegate = self
        }
        if let cell = cell as? TextMessageCell {
            cell.contentLabel.delegate = self
        }
        if let cell = cell as? AppButtonGroupMessageCell {
            cell.appButtonDelegate = self
        }
        if let cell = cell as? AudioMessageCell {
            cell.audioMessagePlayingManager = AudioMessagePlayingManager.shared
        }
        if let cell = cell as? MessageCell {
            CATransaction.performWithoutAnimation {
                cell.render(viewModel: viewModel)
                cell.layoutIfNeeded()
            }
        }
        if let cell = cell as? AppCardV1MessageCell {
            cell.appButtonDelegate = self
            cell.cardContentView.descriptionLabel?.delegate = self
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource?.dates.count ?? 0
    }
    
}

// MARK: - UIScrollViewDelegate
extension ConversationViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateAccessoryButtons(animated: !isAppearanceAnimating)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        didManuallyStoppedTableViewDecelerating = false
        UIView.animate(withDuration: animationDuration) {
            self.tableView.setFloatingHeaderViewsHidden(false, animated: false)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            didManuallyStoppedTableViewDecelerating = true
            tableView.setFloatingHeaderViewsHidden(true, animated: true, delay: 0.5)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if !tableView.isTracking && !didManuallyStoppedTableViewDecelerating {
            tableView.setFloatingHeaderViewsHidden(true, animated: true)
        }
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        // With this implementation tableView will scroll to {0, 0}, or it will scrolls all the way up to first message in this conversation
        if tableView.numberOfSections >= 1, tableView.numberOfRows(inSection: 0) >= 1 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
        return false
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.tableView.setFloatingHeaderViewsHidden(true, animated: true, delay: 1)
        }
        if let id = self.messageIdToFlashAfterAnimationFinished, let indexPath = self.dataSource.indexPath(where: { $0.messageId == id }) {
            if self.flashCellBackground(at: indexPath) {
                self.messageIdToFlashAfterAnimationFinished = nil
            }
        }
    }
    
}

// MARK: - UITableViewDelegate
extension ConversationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MessageCell, let viewModel = cell.viewModel {
            CATransaction.performWithoutAnimation {
                if tableView.allowsMultipleSelection {
                    let intent = multipleSelectionActionView.intent
                    let availability = self.viewModel(viewModel, availabilityForMultipleSelectionWith: intent)
                    switch availability {
                    case .available:
                        cell.setMultipleSelecting(true, animated: false)
                    case .visibleButUnavailable:
                        cell.setMultipleSelecting(true, animated: false)
                        cell.checkmarkView.status = .nonSelectable
                    case .invisible:
                        cell.setMultipleSelecting(false, animated: false)
                    }
                } else {
                    cell.setMultipleSelecting(false, animated: false)
                }
                cell.layoutIfNeeded()
            }
        }
        guard let dataSource = dataSource else {
            return
        }
        if !isAppearanceAnimating {
            // Keep focusIndexPath until viewDidAppear
            dataSource.focusIndexPath = indexPath
        }
        if indexPath.section == 0 && indexPath.row <= loadMoreMessageThreshold {
            dataSource.loadMoreAboveIfNeeded()
        }
        if let lastIndexPath = dataSource.lastIndexPath, indexPath.section == lastIndexPath.section, indexPath.row >= lastIndexPath.row - loadMoreMessageThreshold {
            dataSource.loadMoreBelowIfNeeded()
        }
        
        if let viewModel = dataSource.viewModel(for: indexPath) {
            let message = viewModel.message
            let messageId = message.messageId
            
            if let viewModel = viewModel as? AttachmentLoadingViewModel, viewModel.automaticallyLoadsAttachment {
                viewModel.beginAttachmentLoading(isTriggeredByUser: false)
                (cell as? AttachmentLoadingMessageCell)?.updateOperationButtonStyle()
            }
            if viewModel is InscriptionMessageViewModel, message.inscription == nil, let snapshotID = message.snapshotId {
                DispatchQueue.global().async {
                    guard let hash = SafeSnapshotDAO.shared.inscriptionHash(snapshotID: snapshotID), !hash.isEmpty else {
                        return
                    }
                    let job = RefreshInscriptionJob(inscriptionHash: hash)
                    job.snapshotID = snapshotID
                    job.messageID = messageId
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            }
            if messageId == dataSource.firstUnreadMessageId || cell is UnreadHintMessageCell {
                unreadBadgeValue = 0
                dataSource.firstUnreadMessageId = nil
            }
            if messageId == quotingMessageId {
                quotingMessageId = nil
            }
            if let hasMentionRead = message.hasMentionRead, !hasMentionRead {
                message.hasMentionRead = true
                mentionScrollingDestinations.removeAll(where: { $0 == message.messageId })
                dataSource.queue.async {
                    SendMessageService.shared.sendMentionMessageRead(conversationId: message.conversationId,
                                                                     messageId: message.messageId)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? PhotoRepresentableMessageCell {
            setCell(cell, contentViewHidden: false)
        }
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        if let viewModel = viewModel as? AttachmentLoadingViewModel {
            viewModel.cancelAttachmentLoading(isTriggeredByUser: false)
        }
        if viewModel.message.messageId == quotingMessageId, let lastVisibleIndexPath = tableView.indexPathsForVisibleRows?.last, lastVisibleIndexPath.section > indexPath.section || (lastVisibleIndexPath.section == indexPath.section && lastVisibleIndexPath.row > indexPath.row) {
            quotingMessageId = nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return 44
        }
        if viewModel.cellHeight.isNaN || viewModel.cellHeight < 1 {
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
            header.label.text = DateFormatter.yyyymmdd.date(from: date)?.chatTimeAgo()
        }
        return header
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        nil
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if let label = tableView.hitTest(point, with: nil) as? CoreTextLabel, label.canResponseTouch(at: tableView.convert(point, to: label)) {
            return nil
        } else {
            return contextMenuConfigurationForRow(at: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
    func tableView(_ tableView: UITableView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        if let animator = animator {
            animator.addCompletion(dataSource.performPendingMessagePinningUpdate)
        } else {
            dataSource.performPendingMessagePinningUpdate()
        }
    }
    
}

// MARK: - DetailInfoMessageCellDelegate
extension ConversationViewController: DetailInfoMessageCellDelegate {
    
    func detailInfoMessageCellDidSelectFullname(_ cell: DetailInfoMessageCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let message = dataSource?.viewModel(for: indexPath)?.message,
            let user = UserDAO.shared.getUser(userId: message.userId)
        else {
            return
        }
        let vc = UserProfileViewController(user: user)
        present(vc, animated: true, completion: nil)
    }
    
}

// MARK: - AppButtonDelegate
extension ConversationViewController: AppButtonDelegate {
    
    func appButtonCell(_ cell: MessageCell, didSelectActionAt index: Int) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let message = dataSource?.viewModel(for: indexPath)?.message
        else {
            return
        }
        if let appButtons = message.appButtons {
            if index < appButtons.count {
                openAction(action: appButtons[index].action, sendUserId: message.userId)
            }
        } else if case let .v1(content) = message.appCard {
            if index < content.actions.count {
                openAction(action: content.actions[index].action,
                           sendUserId: message.userId,
                           shareable: content.isShareable)
            }
        }
    }
    
    func contextMenuConfigurationForAppButtonGroupMessageCell(_ cell: MessageCell) -> UIContextMenuConfiguration? {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return nil
        }
        return contextMenuConfigurationForRow(at: indexPath)
    }
    
    func previewForHighlightingContextMenuOfAppButtonGroupMessageCell(_ cell: MessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
    func previewForDismissingContextMenuOfAppButtonGroupMessageCell(_ cell: MessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
}

// MARK: - AttachmentLoadingMessageCellDelegate
extension ConversationViewController: AttachmentLoadingMessageCellDelegate {
    
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: UITableViewCell & AttachmentLoadingMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let viewModel = dataSource?.viewModel(for: indexPath) as? MessageViewModel & AttachmentLoadingViewModel else {
            return
        }
        switch viewModel.operationButtonStyle {
        case .download, .upload:
            viewModel.beginAttachmentLoading(isTriggeredByUser: true)
        case .busy:
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
        case .expired, .finished:
            break
        }
        cell.updateOperationButtonStyle()
    }
    
}

// MARK: - CoreTextLabelDelegate
extension ConversationViewController: UITextViewDelegate {
    
    // Works for UITextView in AnnouncementBadgeContentView
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if !openUrlOutsideApplication(URL) {
            open(url: URL)
        }
        return false
    }
    
}

// MARK: - CoreTextLabelDelegate
extension ConversationViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        handleTapping(on: url)
        textPreviewRecognizer.isEnabled = false
        textPreviewRecognizer.isEnabled = true
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        handleLongPressing(on: url)
    }
    
}

// MARK: - UIImagePickerControllerDelegate
extension ConversationViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        picker.presentingViewController?.dismiss(animated: true) {
            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            let preview = MediaPreviewViewController(resource: .image(image))
            preview.conversationInputViewController = self.conversationInputViewController
            self.present(preview, animated: true)
        }
    }
    
}

// MARK: - UINavigationControllerDelegate
extension ConversationViewController: UINavigationControllerDelegate {
    // Required by UIImagePickerController for no reason
}

// MARK: - UIDocumentPickerDelegate
extension ConversationViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard urls.count > 0 else {
            return
        }
        documentPicker(controller, didPickDocumentAt: urls[0])
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        let vc = FileSendViewController.instance(documentUrl: url, conversationInputViewController: conversationInputViewController)
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

// MARK: - UIDocumentInteractionControllerDelegate
extension ConversationViewController: UIDocumentInteractionControllerDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        previewDocumentController = nil
        previewDocumentMessageId = nil
    }
    
}

// MARK: - GalleryViewControllerDelegate
extension ConversationViewController: GalleryViewControllerDelegate {
    
    func galleryViewController(_ viewController: GalleryViewController, cellFor item: GalleryItem) -> GalleryTransitionSource? {
        return visiblePhotoRepresentableCell(of: item.messageId)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willShow item: GalleryItem) {
        guard UIApplication.homeContainerViewController?.pipController?.item != item else {
            return
        }
        setCell(ofMessageId: item.messageId, contentViewHidden: true)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem) {
        setCell(ofMessageId: item.messageId, contentViewHidden: false)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willDismiss item: GalleryItem) {
        setCell(ofMessageId: item.messageId, contentViewHidden: true)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem) {
        setCell(ofMessageId: item.messageId, contentViewHidden: false)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didDismiss item: GalleryItem, relativeOffset: CGFloat?) {
        if let offset = relativeOffset, let indexPath = dataSource?.indexPath(where: { $0.messageId == item.messageId }), let cell = tableView.cellForRow(at: indexPath) as? PhotoRepresentableMessageCell {
            (dataSource.viewModel(for: indexPath) as? PhotoRepresentableMessageViewModel)?.layoutPosition = .relativeOffset(offset)
            cell.contentImageWrapperView.position = .relativeOffset(offset)
            cell.contentImageWrapperView.layoutIfNeeded()
        }
        setCell(ofMessageId: item.messageId, contentViewHidden: false)
    }
    
}

// MARK: - TextPreviewViewDelegate
extension ConversationViewController: TextPreviewViewDelegate {
    
    func textPreviewView(_ view: TextPreviewView, didSelectURL url: URL) {
        handleTapping(on: url)
    }
    
    func textPreviewView(_ view: TextPreviewView, didLongPressURL url: URL) {
        handleLongPressing(on: url)
    }
    
}

// MARK: - PinMessageBannerViewDelegate
extension ConversationViewController: PinMessageBannerViewDelegate {
    
    func pinMessageBannerViewDidTapPin(_ view: PinMessageBannerView) {
        let vc = PinMessagesPreviewViewController(conversationId: conversationId, isGroup: dataSource.category == .group)
        vc.delegate = self
        vc.presentAsChild(of: self)
    }
    
    func pinMessageBannerViewDidTapClose(_ view: PinMessageBannerView) {
        AppGroupUserDefaults.User.pinMessageBanners[conversationId] = nil
    }
    
    func pinMessageBannerViewDidTapPreview(_ view: PinMessageBannerView) {
        guard let id = AppGroupUserDefaults.User.pinMessageBanners[conversationId],
              let quoteMessageId = MessageDAO.shared.quoteMessageId(messageId: id) else {
            return
        }
        scrollToMessage(messageId: quoteMessageId)
    }
    
}

// MARK: - PinMessagesPreviewViewControllerDelegate
extension ConversationViewController: PinMessagesPreviewViewControllerDelegate {
    
    func pinMessagesPreviewViewController(_ controller: PinMessagesPreviewViewController, needsShowMessage messageId: String) {
        controller.dismissAsChild(animated: true) {
            self.scrollToMessage(messageId: messageId)
        }
    }
    
}

// MARK: - Message Actions
extension ConversationViewController {
    
    private func availableActions(for message: MessageItem) -> [MessageAction] {
        let status = message.status
        let category = message.category
        let mediaStatus = message.mediaStatus
        
        var actions: [MessageAction]
        if status == MessageStatus.FAILED.rawValue || status == MessageStatus.UNKNOWN.rawValue || category.hasPrefix("WEBRTC_") {
            actions = [.delete]
        } else if category.hasSuffix("_TEXT") || category.hasSuffix("_POST") {
            actions = [.reply, .forward, .copy, .delete]
        } else if category.hasSuffix("_STICKER") {
            actions = [.addToStickers, .reply, .forward, .delete]
        } else if category.hasSuffix("_CONTACT") || category.hasSuffix("_LIVE") {
            actions = [.reply, .forward, .delete]
        } else if category.hasSuffix("_IMAGE") {
            if mediaStatus == MediaStatus.DONE.rawValue || mediaStatus == MediaStatus.READ.rawValue {
                actions = [.addToStickers, .reply, .forward, .delete]
            } else {
                actions = [.reply, .delete]
            }
        } else if category.hasSuffix("_DATA") || category.hasSuffix("_VIDEO") || category.hasSuffix("_AUDIO") {
            if mediaStatus == MediaStatus.DONE.rawValue || mediaStatus == MediaStatus.READ.rawValue {
                actions = [.reply, .forward, .delete]
            } else {
                actions = [.reply, .delete]
            }
        } else if category.hasSuffix("_LOCATION") {
            actions = [.forward, .reply, .delete]
        } else if category.hasSuffix("_TRANSCRIPT") {
            actions = [.reply, .delete]
            if message.mediaStatus == MediaStatus.DONE.rawValue {
                actions.insert(.forward, at: 0)
            }
        } else if ["SYSTEM_ACCOUNT_SNAPSHOT", "SYSTEM_SAFE_SNAPSHOT", "SYSTEM_SAFE_INSCRIPTION"].contains(category) {
            actions = [.delete]
        } else if category == MessageCategory.APP_CARD.rawValue {
            actions = [.forward, .reply, .delete]
        } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
            actions = [.delete]
        } else if category == MessageCategory.MESSAGE_RECALL.rawValue {
            actions = [.delete]
        } else {
            actions = []
        }
        if ConversationViewController.allowReportSingleMessage {
            actions.append(.report)
        }
        if canPinMessages, status != MessageStatus.SENDING.rawValue, status != MessageStatus.UNKNOWN.rawValue {
            let index: Int?
            if let replyIndex = actions.firstIndex(of: .reply) {
                index = replyIndex + 1
            } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
                index = 0
            } else {
                index = nil
            }
            if let index = index {
                let action: MessageAction = pinnedMessageIds.contains(message.messageId) ? .unpin : .pin
                actions.insert(action, at: index)
            }
        }
        return actions
    }
    
    private func performActionOnSelectedRow(_ action: MessageAction) {
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        perform(action: action, onRowAt: indexPath)
    }
    
    private func perform(action: MessageAction, onRowAt indexPath: IndexPath) {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        let message = viewModel.message
        switch action {
        case .copy:
            if ["_TEXT", "_POST"].contains(where: message.category.hasSuffix(_:)) {
                UIPasteboard.general.string = message.content
            }
        case .delete:
            beginMultipleSelection(on: indexPath, intent: .delete)
        case .forward:
            beginMultipleSelection(on: indexPath, intent: .forward)
        case .reply:
            conversationInputViewController.quote = (message, viewModel.thumbnail)
        case .addToStickers:
            if message.category.hasSuffix("_STICKER"), let stickerId = message.stickerId {
                StickerAPI.addSticker(stickerId: stickerId, completion: { (result) in
                    switch result {
                    case let .success(sticker):
                        DispatchQueue.global().async {
                            StickerDAO.shared.insertOrUpdateFavoriteSticker(sticker: sticker)
                            showAutoHiddenHud(style: .notification, text: R.string.localizable.added())
                        }
                    case let .failure(error):
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                })
            } else {
                let vc = StickerAddViewController(source: .message(message))
                navigationController?.pushViewController(vc, animated: true)
            }
        case .report:
            report(conversationId: conversationId, message: message)
        case .pin:
            dataSource.postponeMessagePinningUpdate(with: message.messageId)
            SendMessageService.shared.sendPinMessages(items: [message], conversationId: conversationId, action: .pin)
        case .unpin:
            dataSource.postponeMessagePinningUpdate(with: message.messageId)
            SendMessageService.shared.sendPinMessages(items: [message], conversationId: conversationId, action: .unpin)
        }
    }
    
}

// MARK: - UI Related Helpers
extension ConversationViewController {
    
    private func updateNavigationBar() {
        let membershipIcon: UIImage?
        if dataSource.category == .group {
            let conversation = dataSource.conversation
            titleLabel.text = conversation.name
            avatarImageView.setGroupImage(with: conversation.iconUrl)
            membershipIcon = nil
        } else if let user = ownerUser {
            subtitleLabel.text = user.identityNumber
            titleLabel.text = user.fullName
            avatarImageView.setImage(with: user)
            membershipIcon = user.membership?.badgeImage
        } else {
            membershipIcon = nil
        }
        if let membershipIcon {
            membershipIconView.image = membershipIcon
            membershipIconView.isHidden = false
            if membershipButton == nil {
                let button = UIButton()
                button.addTarget(self, action: #selector(buyOpponentMembership(_:)), for: .touchUpInside)
                navigationBarContentView.addSubview(button)
                button.snp.makeConstraints { make in
                    make.width.height.equalTo(30)
                    make.center.equalTo(membershipIconView)
                }
                membershipButton = button
            }
        } else {
            membershipIconView.isHidden = true
            membershipButton?.removeFromSuperview()
        }
    }
    
    private func updateSubtitleAndInputBar() {
        let conversationId = dataSource.conversationId
        dataSource.queue.async { [weak self] in
            let count = ParticipantDAO.shared.getParticipantCount(conversationId: conversationId)
            let isParticipant = ParticipantDAO.shared.userId(myUserId, isParticipantOfConversationId: conversationId)
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.numberOfParticipants = count
                weakSelf.isMember = isParticipant
                weakSelf.conversationInputViewController.deleteConversationButton.isHidden = isParticipant
                weakSelf.conversationInputViewController.inputBarView.isHidden = false
                weakSelf.subtitleLabel.text = R.string.localizable.participants_count("\(count)")
            }
        }
    }
    
    private func updateNavigationBarPositionWithInputWrapperViewHeight(oldHeight: CGFloat, newHeight: CGFloat) {
        let diff = newHeight - oldHeight
        if conversationInputViewController.isMaximizable && newHeight > conversationInputViewController.regularHeight {
            let top = navigationBarTopConstraint.constant + diff
            let maxTop = navigationBarView.frame.height
            let navigationBarTop = min(maxTop, max(0, top))
            navigationBarTopConstraint.constant = navigationBarTop
            tableView.contentInset.top = max(view.safeAreaInsets.top, navigationBarView.frame.height - navigationBarTop)
            tableView.verticalScrollIndicatorInsets.top = tableView.contentInset.top
            if !statusBarHidden {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
                    self.statusBarHidden = true
                }, completion: nil)
            }
        } else {
            navigationBarTopConstraint.constant = 0
            tableView.contentInset.top = titleViewTopConstraint.constant + titleViewHeightConstraint.constant
            tableView.verticalScrollIndicatorInsets.top = tableView.contentInset.top
            if statusBarHidden {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
                    self.statusBarHidden = false
                }, completion: nil)
            }
        }
    }
    
    private func updateAccessoryButtons(animated: Bool) {
        let position = tableView.contentSize.height - tableView.contentOffset.y - tableView.bounds.height
        let didReachThreshold = position > showScrollToBottomButtonThreshold
        let shouldShowScrollToBottomButton = didReachThreshold || !dataSource.didLoadLatestMessage
        if scrollToBottomWrapperView.alpha < 0.1 && shouldShowScrollToBottomButton {
            scrollToBottomWrapperHeightConstraint.constant = 48
            if animated {
                UIView.animate(withDuration: animationDuration) {
                    self.scrollToBottomWrapperView.alpha = 1
                    self.view.layoutIfNeeded()
                }
            } else {
                scrollToBottomWrapperView.alpha = 1
            }
        } else if scrollToBottomWrapperView.alpha > 0.9 && !shouldShowScrollToBottomButton {
            scrollToBottomWrapperHeightConstraint.constant = 5
            if animated {
                UIView.animate(withDuration: animationDuration) {
                    self.scrollToBottomWrapperView.alpha = 0
                    self.view.layoutIfNeeded()
                }
            } else {
                scrollToBottomWrapperView.alpha = 0
            }
            unreadBadgeValue = 0
            dataSource?.firstUnreadMessageId = nil
        }
    }
    
    private func updateStrangerActionView() {
        guard dataSource.category == .contact else {
            return
        }
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            if let ownerUser = self?.ownerUser, ownerUser.relationship == Relationship.STRANGER.rawValue, !MessageDAO.shared.hasSentMessage(inConversationOf: conversationId) {
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    if ownerUser.isBot {
                        weakSelf.tableView.tableFooterView = weakSelf.appReceptionView
                    } else {
                        weakSelf.tableView.tableFooterView = weakSelf.strangerHintView
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.tableView.tableFooterView = nil
                }
            }
        }
    }
    
    private func updateInvitationHintView() {
        guard dataSource.category == .group else {
            return
        }
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            let isParticipant = ParticipantDAO.shared.userId(myUserId, isParticipantOfConversationId: conversationId)
            guard isParticipant else {
                DispatchQueue.main.async {
                    self?.tableView.tableFooterView = nil
                }
                return
            }
            let isInvitedByStranger: Bool
            let myInvitation = MessageDAO.shared.getInvitationMessage(conversationId: conversationId, inviteeUserId: myUserId)
            if let inviterId = myInvitation?.userId, !MessageDAO.shared.hasSentMessage(inConversationOf: conversationId), let inviter = UserDAO.shared.getUser(userId: inviterId), inviter.relationship != Relationship.FRIEND.rawValue {
                isInvitedByStranger = true
            } else {
                isInvitedByStranger = false
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.myInvitation = myInvitation
                self.tableView.tableFooterView = isInvitedByStranger ? self.invitationHintView : nil
            }
        }
    }
    
    private func updateNavigationBarHeightAndTableViewTopInset() {
        titleViewTopConstraint.constant = max(20, AppDelegate.current.mainWindow.safeAreaInsets.top)
        tableView.contentInset.top = titleViewTopConstraint.constant + titleViewHeightConstraint.constant
        tableView.verticalScrollIndicatorInsets.top = tableView.contentInset.top
    }
    
    // Returns true if the animation succeeds to perform, or false if cell not found
    @discardableResult
    private func flashCellBackground(at indexPath: IndexPath) -> Bool {
        guard let cell = self.tableView.cellForRow(at: indexPath) as? DetailInfoMessageCell else {
            return false
        }
        cell.updateAppearance(highlight: true, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            cell.updateAppearance(highlight: false, animated: true)
        })
        return true
    }
    
    private func scheduleCellBackgroundFlash(messageId: String) {
        let visibleIndexPath = tableView.indexPathsForVisibleRows?.first(where: { (indexPath) -> Bool in
            guard let viewModel = dataSource.viewModel(for: indexPath) else {
                return false
            }
            return viewModel.message.messageId == messageId
        })
        if let indexPath = visibleIndexPath {
            _ = flashCellBackground(at: indexPath)
        } else {
            messageIdToFlashAfterAnimationFinished = messageId
        }
    }
    
    private func setCell(ofMessageId id: String?, contentViewHidden hidden: Bool) {
        guard let id = id, let cell = visiblePhotoRepresentableCell(of: id) else {
            return
        }
        setCell(cell, contentViewHidden: hidden)
    }
    
    private func setCell(_ cell: PhotoRepresentableMessageCell, contentViewHidden hidden: Bool) {
        var contentViews = [
            cell.contentImageView,
            cell.timeLabel,
            cell.statusImageView
        ]
        if let cell = cell as? AttachmentExpirationHintingMessageCell {
            contentViews.append(cell.operationButton)
        }
        if let cell = cell as? VideoMessageCell {
            contentViews.append(cell.lengthLabel)
        }
        if let cell = cell as? LiveMessageCell {
            contentViews.append(cell.badgeView)
            contentViews.append(cell.playButton)
        }
        contentViews.forEach {
            $0.isHidden = hidden
        }
    }
    
    private func frameOfPhotoRepresentableCell(_ cell: PhotoRepresentableMessageCell) -> CGRect {
        var rect = cell.contentImageView.convert(cell.contentImageView.bounds, to: view)
        if UIApplication.shared.statusBarHeight == StatusBarHeight.inCall {
            rect.origin.y += (StatusBarHeight.inCall - StatusBarHeight.normal)
        }
        return rect
    }
    
    private func visiblePhotoRepresentableCell(of messageId: String) -> PhotoRepresentableMessageCell? {
        for case let cell as PhotoRepresentableMessageCell in tableView.visibleCells {
            if cell.viewModel?.message.messageId == messageId {
                return cell
            }
        }
        return nil
    }
    
    private func loadUserHandleAsChildIfNeeded() {
        guard userHandleViewController.parent == nil else {
            return
        }
        addChild(userHandleViewController)
        view.insertSubview(userHandleViewController.view, belowSubview: inputWrapperView)
        userHandleViewController.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBarView.snp.bottom)
            make.bottom.equalTo(inputWrapperView.snp.top)
        }
        userHandleViewController.didMove(toParent: self)
    }
    
    private func beginMultipleSelection(on indexPath: IndexPath, intent: MultipleSelectionIntent) {
        conversationInputViewController.textView.resignFirstResponder()
        conversationInputViewController.audioViewController.cancelIfRecording()
        UIView.performWithoutAnimation {
            navigationBarView.addSubview(cancelSelectionButton)
            cancelSelectionButton.snp.makeConstraints { (make) in
                make.leading.bottom.equalToSuperview()
                make.height.equalTo(56)
            }
            navigationBarView.layoutIfNeeded()
        }
        tableView.allowsMultipleSelection = true
        for cell in tableView.visibleCells {
            guard let cell = cell as? MessageCell, let viewModel = cell.viewModel else {
                continue
            }
            let availability = self.viewModel(viewModel, availabilityForMultipleSelectionWith: intent)
            switch availability {
            case .available:
                cell.setMultipleSelecting(true, animated: true)
            case .visibleButUnavailable:
                cell.setMultipleSelecting(true, animated: true)
                cell.checkmarkView.status = .nonSelectable
            case .invisible:
                cell.setMultipleSelecting(false, animated: true)
            }
        }
        multipleSelectionActionView.intent = intent
        multipleSelectionActionView.frame = CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: multipleSelectionActionView.preferredHeight)
        multipleSelectionActionView.autoresizingMask = [.flexibleWidth]
        view.addSubview(multipleSelectionActionView)
        
        showInputWrapperConstraint.priority = .defaultLow
        hideInputWrapperConstraint.priority = .defaultHigh
        UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                let y = self.view.bounds.height - self.multipleSelectionActionView.preferredHeight
                self.multipleSelectionActionView.frame.origin.y = y
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                let old = self.inputWrapperHeightConstraint.constant
                let new = self.multipleSelectionActionView.preferredHeight
                self.updateTableViewBottomInsetWithBottomBarHeight(old: old, new: new, animated: false)
            }
        }, completion: nil)
        DispatchQueue.main.async {
            guard let viewModel = self.dataSource.viewModel(for: indexPath) else {
                return
            }
            let availability = self.viewModel(viewModel, availabilityForMultipleSelectionWith: intent)
            switch availability {
            case .available:
                self.multipleSelectionActionView.numberOfSelection = 1
                self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                self.dataSource.selectedViewModels[viewModel.message.messageId] = viewModel
            case let .visibleButUnavailable(reason):
                self.multipleSelectionActionView.numberOfSelection = 0
                self.presentGotItAlertController(title: reason)
            case .invisible:
                break
            }
        }
    }
    
    private func updateTableViewBottomInsetWithBottomBarHeight(old: CGFloat, new: CGFloat, animated: Bool) {
        
        func layout() {
            updateNavigationBarPositionWithInputWrapperViewHeight(oldHeight: old, newHeight: new)
            let bottomInset = new + MessageViewModel.bottomSeparatorHeight
            
            var newContentOffsetY = tableView.contentOffset.y + bottomInset - tableView.contentInset.bottom
            if isAppearanceAnimating, let focusIndexPath = dataSource?.focusIndexPath {
                let focusRectY = tableView.rectForRow(at: focusIndexPath).origin.y
                let availableSpace = focusRectY
                    - tableView.contentOffset.y
                    - tableView.contentInset.top
                    - ConversationDateHeaderView.height
                if availableSpace > 0 {
                    newContentOffsetY = min(newContentOffsetY, tableView.contentOffset.y + availableSpace)
                } else {
                    newContentOffsetY = tableView.contentOffset.y
                }
            }
            tableView.contentInset.bottom = bottomInset
            if adjustTableViewContentOffsetWhenInputWrapperHeightChanges {
                tableView.setContentOffsetYSafely(newContentOffsetY)
            }
            if view.window != nil {
                view.layoutIfNeeded()
            }
        }
        
        tableView.verticalScrollIndicatorInsets.bottom = new - view.safeAreaInsets.bottom
        if animated {
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           options: .overdampedCurve,
                           animations: layout)
        } else {
            UIView.performWithoutAnimation(layout)
        }
    }
    
    // Announcement badge will be hidden if announcement passed in is nil or empty
    private func updateAnnouncementBadge(announcement: String?) {
        if let announcement = announcement, !announcement.isEmpty {
            if announcementBadgeContentView.superview == nil {
                announcementBadgeView.addSubview(announcementBadgeContentView)
                announcementBadgeContentView.snp.makeEdgesEqualToSuperview()
                announcementBadgeContentView.textView.delegate = self
            }
            announcementBadgeContentView.textView.text = announcement
            announcementBadgeContentView.layoutAsCompressed()
        } else {
            for subview in announcementBadgeView.subviews {
                subview.removeFromSuperview()
            }
        }
    }
    
    private func showScamAnnouncementIfNeeded() {
        guard let user = self.ownerUser else {
            return
        }
        guard user.isScam else {
            updateAnnouncementBadge(announcement: nil)
            return
        }
        let shouldShowAnnouncement: Bool
        if let date = AppGroupUserDefaults.User.closeScamAnnouncementDate[user.userId] {
            shouldShowAnnouncement = abs(date.timeIntervalSinceNow) > .day
        } else {
            shouldShowAnnouncement = true
        }
        if shouldShowAnnouncement {
            announcementBadgeContentView.iconView.image = R.image.ic_warning()?.withRenderingMode(.alwaysOriginal)
            updateAnnouncementBadge(announcement: R.string.localizable.scam_warning())
        } else {
            updateAnnouncementBadge(announcement: nil)
        }
    }
    
    @objc private func updateGroupCallIndicatorViewHidden() {
        let service = CallService.shared
        if let call = service.activeCall, call.conversationId == conversationId {
            if let view = groupCallIndicatorViewIfLoaded {
                view.isHidden = true
            }
        } else {
            let ids = service.membersManager.memberIds(forConversationWith: conversationId)
            if ids.isEmpty {
                groupCallIndicatorViewIfLoaded?.isHidden = true
            } else {
                groupCallIndicatorView.isHidden = false
            }
        }
    }
    
    private func layoutGroupCallIndicatorView() {
        guard let indicator = groupCallIndicatorViewIfLoaded, let constraint = groupCallIndicatorCenterYConstraint else {
            return
        }
        let (minY, maxY) = groupCallIndicatorCenterYLimitation
        let y = max(minY, min(maxY, indicator.center.y))
        constraint.constant = y
    }
    
    private func updatePinMessagePreview(item: MessageItem) {
        let preview = TransferPinAction.pinMessage(item: item).replacingOccurrences(of: "\n\n", with: "\n")
        pinMessageBannerView.update(preview: preview)
        pinMessageBannerView.snp.updateConstraints { make in
            make.left.equalTo(0)
        }
    }
    
    private func hidePinMessagePreview() {
        pinMessageBannerView.hideMessagePreview()
        pinMessageBannerView.snp.updateConstraints { make in
            make.left.equalTo(AppDelegate.current.mainWindow.bounds.width - 60)
        }
    }
    
}

// MARK: - Helpers
extension ConversationViewController {
    
    private func finishInitialLoading() {
        resizeInputRecognizer = ResizeInputWrapperGestureRecognizer(target: self, action: #selector(resizeInputWrapperAction(_:)))
        if let popRecognizer = navigationController?.interactivePopGestureRecognizer {
            resizeInputRecognizer.require(toFail: popRecognizer)
        }
        resizeInputRecognizer.delegate = self
        tableView.addGestureRecognizer(resizeInputRecognizer)
        
        updateAccessoryButtons(animated: false)
        conversationInputViewController.finishLoading()
        let isGroup = dataSource.category == .group
        if isGroup {
            updateInvitationHintView()
        }
        hideLoading()
        let conversationId = self.conversationId
        dataSource.queue.async { [weak self] in
            let users = ParticipantDAO.shared.getParticipants(conversationId: conversationId)
            var ids = MessageMentionDAO.shared.unreadMessageIds(conversationId: conversationId)
            let hasPinMessage = PinMessageDAO.shared.hasMessage(conversationId: conversationId)
            let visiblePinMessage: MessageItem?
            if let id = AppGroupUserDefaults.User.pinMessageBanners[conversationId] {
                visiblePinMessage = MessageDAO.shared.getFullMessage(messageId: id)
            } else {
                visiblePinMessage = nil
            }
            let pinnedMessageIds = Set(PinMessageDAO.shared.messageItems(conversationId: conversationId).map(\.messageId))
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.pinnedMessageIds = pinnedMessageIds
                UIView.performWithoutAnimation {
                    self.userHandleViewController.users = users
                    if isGroup {
                        let keyword = self.conversationInputViewController.textView.inputingMentionToken
                        self.userHandleViewController.reload(with: keyword) { (hasContent) in
                            self.isUserHandleHidden = !hasContent
                        }
                    }
                    ids.removeAll(where: self.dataSource.visibleMessageIds.contains)
                    self.mentionScrollingDestinations = ids
                    if hasPinMessage {
                        self.pinMessageBannerView.isHidden = false
                        if let item = visiblePinMessage {
                            self.updatePinMessagePreview(item: item)
                        } else {
                            self.hidePinMessagePreview()
                        }
                        self.layoutGroupCallIndicatorView()
                    }
                }
            }
            self?.updateMessagePinningAvailability()
        }
    }
    
    private func openDocumentAction(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        let url = AttachmentContainer.url(for: .files, filename: mediaUrl)
        guard FileManager.default.fileExists(atPath: url.path)  else {
            return
        }
        previewDocumentController = UIDocumentInteractionController(url: url)
        previewDocumentController?.delegate = self
        if !(previewDocumentController?.presentPreview(animated: true) ?? false) {
            previewDocumentController?.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
        }
        previewDocumentMessageId = message.messageId
    }
    
    private func showLoading() {
        loadingView.startAnimating()
        titleStackView.isHidden = true
    }
    
    private func hideLoading() {
        loadingView.stopAnimating()
        titleStackView.isHidden = false
    }
    
    private func openAppCard(appCard: AppCardData, sendUserId: String) {
        guard case let .v0(appCard) = appCard else {
            return
        }
        let action = appCard.action.absoluteString
        let isShareable = appCard.isShareable
        if let appId = appCard.appId, !appId.isEmpty {
            DispatchQueue.global().async { [weak self] in
                var app = AppDAO.shared.getApp(appId: appId)
                if app == nil {
                    if case let .success(response) = UserAPI.showUser(userId: appId) {
                        UserDAO.shared.updateUsers(users: [response])
                        app = response.app
                    }
                }
                
                DispatchQueue.main.async {
                    self?.open(url: appCard.action, app: app, shareable: isShareable)
                }
            }
        } else {
            openAction(action: action, sendUserId: sendUserId, shareable: isShareable)
        }
    }
    
    private func openAction(action: String, sendUserId: String, shareable: Bool? = nil) {
        guard !openInputAction(action: action) else {
            return
        }
        guard let url = URL(string: action) else {
            return
        }
        if let app = composer.opponentApp, app.appId == sendUserId {
            open(url: url, app: app, shareable: shareable)
        } else {
            DispatchQueue.global().async { [weak self] in
                var app = AppDAO.shared.getApp(ofUserId: sendUserId)
                if app == nil {
                    if case let .success(response) = UserAPI.showUser(userId: sendUserId) {
                        UserDAO.shared.updateUsers(users: [response])
                        app = response.app
                    }
                }
                DispatchQueue.main.async {
                    self?.open(url: url, app: app, shareable: shareable)
                }
            }
        }
    }
    
    private func openInputAction(action: String) -> Bool {
        guard action.hasPrefix("input:"), action.count > 6 else {
            return false
        }
        let inputAction = String(action.suffix(action.count - 6))
        if !inputAction.isEmpty {
            composer.sendMessage(type: .SIGNAL_TEXT,
                                 quote: nil,
                                 value: inputAction)
        }
        return true
    }
    
    private func open(url: URL, app: App? = nil, shareable: Bool? = nil) {
        let wrapper = WeakWrapper(object: composer!)
        guard !UrlWindow.checkUrl(url: url, from: .conversation(wrapper)) else {
            return
        }
        guard !conversationId.isEmpty else {
            return
        }
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        let context: MixinWebViewController.Context
        if let app = app {
            context = .init(conversationId: conversationId, url: url, app: app, shareable: shareable)
        } else {
            context = .init(conversationId: conversationId, initialUrl: url)
        }
        container.presentWebViewController(context: context)
    }
    
    private func reportAirDop(conversationId: String) {
        DispatchQueue.global().async {
            let info: Logger.UserInfo = [
                "isReachable": ReachabilityManger.shared.isReachable,
                "isConnected": WebSocketService.shared.isConnected,
                "isRealConnected": WebSocketService.shared.isRealConnected
            ]
            Logger.conversation(id: conversationId).info(category: "Report", message: "Exported logs", userInfo: info)
            guard let targetUrl = Logger.export(conversationID: conversationId), FileManager.default.fileSize(targetUrl.path) > 0 else {
                return
            }
            
            DispatchQueue.main.async {
                let inviteController = UIActivityViewController(activityItems: [targetUrl], applicationActivities: nil)
                self.navigationController?.present(inviteController, animated: true, completion: nil)
            }
        }
    }
    
    private func report(conversationId: String, message: MessageItem? = nil) {
        DispatchQueue.global().async { [weak self] in
            let developID = myIdentityNumber == "762532" ? "31911" : "762532"
            var user = UserDAO.shared.getUser(identityNumber: developID)
            if user == nil {
                switch UserAPI.search(keyword: developID) {
                case let .success(userResponse):
                    UserDAO.shared.updateUsers(users: [userResponse])
                    user = UserItem.createUser(from: userResponse)
                case .failure:
                    return
                }
            }
            Logger.conversation(id: conversationId).info(category: "Report", message: "isReachable:\(ReachabilityManger.shared.isReachable), isConnected:\(WebSocketService.shared.isConnected), isRealConnected:\(WebSocketService.shared.isRealConnected)")
            
            if let message = message {
                var log = "[Message][\(message.messageId)][\(message.category)][\(message.status)]...userId:\(message.userId)"
                if ["_IMAGE", "_VIDEO", "_AUDIO", "_LIVE"].contains(where: message.category.hasSuffix) {
                    log += """
                            ...mediaStatus:\(message.mediaStatus ?? "")
                            ...mediaUrl:\(message.mediaUrl ?? "")
                            ...mediaMimeType:\(message.mediaMimeType ?? "")
                            ...mediaSize:\(message.mediaSize ?? 0)
                            ...mediaDuration:\(message.mediaDuration ?? 0)
                            ...mediaLocalIdentifier:\(message.mediaLocalIdentifier ?? "")
                            ...mediaWidth:\(message.mediaWidth ?? 0)
                            ...mediaHeight:\(message.mediaHeight ?? 0)\n
                           """
                    
                    if let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty, !mediaUrl.hasPrefix("http") {
                        if message.category.hasSuffix("_IMAGE") {
                            let url = AttachmentContainer.url(for: .photos, filename: mediaUrl)
                            log += "\(url.path)...fileExists:\(FileManager.default.fileExists(atPath: url.path))...fileSize:\(FileManager.default.fileSize(url.path))"
                        } else if message.category.hasSuffix("_VIDEO") {
                            let url = AttachmentContainer.url(for: .videos, filename: mediaUrl)
                            log += "\(url.path)...fileExists:\(FileManager.default.fileExists(atPath: url.path))...fileSize:\(FileManager.default.fileSize(url.path))"
                        }
                    }
                }
                
                Logger.conversation(id: conversationId).info(category: "Report", message: log)
            }
            
            guard let developUser = user, let url = Logger.export(conversationID: conversationId) else {
                return
            }
            let targetUrl = AttachmentContainer.url(for: .files, filename: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: targetUrl)
                try FileManager.default.removeItem(at: url)
            } catch {
                return
            }
            guard FileManager.default.fileSize(targetUrl.path) > 0 else {
                return
            }
            
            let developConversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: developUser.userId)
            var message = Message.createMessage(category: MessageCategory.PLAIN_DATA.rawValue, conversationId: developConversationId, userId: myUserId)
            message.name = url.lastPathComponent
            message.mediaSize = FileManager.default.fileSize(targetUrl.path)
            message.mediaMimeType = FileManager.default.mimeType(ext: url.pathExtension)
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
    
    private func deleteForMe(viewModels: [MessageViewModel]) {
        if let playingMessageId = AudioMessagePlayingManager.shared.playingMessage?.messageId, viewModels.contains(where: { $0.message.messageId == playingMessageId }) {
            AudioMessagePlayingManager.shared.stop()
        }
        for case let viewModel as AttachmentLoadingViewModel in viewModels {
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
        }
        for viewModel in viewModels {
            dataSource?.queue.async { [weak self] in
                let message = viewModel.message
                guard let weakSelf = self, let indexPath = weakSelf.dataSource.indexPath(where: { $0.messageId == message.messageId }) else {
                    return
                }
                let (deleted, childMessageIds) = MessageDAO.shared.deleteMessage(id: message.messageId)
                if deleted {
                    ReceiveMessageService.shared.stopRecallMessage(item: message, childMessageIds: childMessageIds)
                }
                DispatchQueue.main.sync {
                    _ = weakSelf.dataSource?.removeViewModel(at: indexPath)
                    weakSelf.tableView.reloadData()
                    weakSelf.tableView.setFloatingHeaderViewsHidden(true, animated: true)
                }
            }
        }
        endMultipleSelection()
    }
    
    private func deleteForEveryone(viewModels: [MessageViewModel]) {
        if let playingMessageId = AudioMessagePlayingManager.shared.playingMessage?.messageId, viewModels.contains(where: { $0.message.messageId == playingMessageId }) {
            AudioMessagePlayingManager.shared.stop()
        }
        for case let viewModel as AttachmentLoadingViewModel in viewModels {
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
        }
        DispatchQueue.global().async {
            for viewModel in viewModels {
                SendMessageService.shared.recallMessage(item: viewModel.message)
            }
        }
        endMultipleSelection()
    }
    
    private func showRecallTips(viewModels: [MessageViewModel]) {
        let alc = UIAlertController(title: R.string.localizable.chat_recall_delete_alert(), message: "", preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: R.string.localizable.learn_more(), style: .default, handler: { (_) in
            AppGroupUserDefaults.User.hasShownRecallTips = true
            UIApplication.shared.openURL(url: .recallMessage)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .default, handler: { (_) in
            AppGroupUserDefaults.User.hasShownRecallTips = true
            self.deleteForEveryone(viewModels: viewModels)
        }))
        present(alc, animated: true, completion: nil)
    }
    
    private func reloadWithMessageId(_ messageId: String, scrollUpwards: Bool) {
        let scroll = scrollUpwards ? dataSource.scrollToBottomAndReload : dataSource.scrollToTopAndReload
        let flashingId = self.messageIdToFlashAfterAnimationFinished
        self.messageIdToFlashAfterAnimationFinished = nil
        scroll(messageId, {
            guard let indexPath = self.dataSource?.indexPath(where: { $0.messageId == messageId }) else {
                return
            }
            if scrollUpwards {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
            } else {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            }
            self.messageIdToFlashAfterAnimationFinished = flashingId
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        })
    }
    
    private func handleTapping(on url: URL) {
        guard !openUrlOutsideApplication(url) else {
            return
        }
        open(url: url)
    }
    
    private func handleLongPressing(on url: URL) {
        guard url.scheme != MixinInternalURL.scheme else {
            return
        }
        let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.open_url(), style: .default, handler: { [weak self](_) in
            self?.open(url: url)
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.copy(), style: .default, handler: { (_) in
            UIPasteboard.general.string = url.absoluteString
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
            
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func viewModel(_ viewModel: MessageViewModel, availabilityForMultipleSelectionWith intent: MultipleSelectionIntent) -> SelectionAvailability {
        let actions = availableActions(for: viewModel.message)
        switch intent {
        case .forward:
            if actions.contains(.forward) {
                if viewModel.message.category == MessageCategory.APP_CARD.rawValue {
                    if viewModel.message.appCard?.isShareable ?? true {
                        return .available
                    } else {
                        let reason = R.string.localizable.app_card_shareable_false()
                        return .visibleButUnavailable(reason: reason)
                    }
                } else if viewModel.message.category.hasSuffix("_LIVE") {
                    if viewModel.message.live?.isShareable ?? true {
                        return .available
                    } else {
                        let reason = R.string.localizable.live_shareable_false()
                        return .visibleButUnavailable(reason: reason)
                    }
                } else if viewModel.message.category.hasSuffix("_AUDIO") {
                    if viewModel.message.isShareable {
                        return .available
                    } else {
                        let reason = R.string.localizable.audio_shareable_false()
                        return .visibleButUnavailable(reason: reason)
                    }
                } else {
                    return .available
                }
            } else {
                return .invisible
            }
        case .delete:
            return actions.contains(.delete) ? .available : .invisible
        }
    }
    
    private func updateMessagePinningAvailability() {
        let isAvailable = dataSource.category != .group
            || ParticipantDAO.shared.isAdmin(conversationId: conversationId, userId: myUserId)
        DispatchQueue.main.sync {
            self.canPinMessages = isAvailable
        }
    }
    
}

// MARK: - Context menu configs
extension ConversationViewController {
    
    private func contextMenuConfigurationForRow(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard !tableView.allowsMultipleSelection, let message = dataSource.viewModel(for: indexPath)?.message else {
            return nil
        }
        let menuChildren = availableActions(for: message).map { (action) -> UIAction in
            UIAction(title: action.title, image: action.image) { (_) in
                guard let indexPath = self.dataSource.indexPath(where: { $0.messageId == message.messageId }) else {
                    return
                }
                if action == .delete || action == .forward || action == .reply {
                    // Wait until context menu animation finished
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.perform(action: action, onRowAt: indexPath)
                    }
                } else {
                    self.perform(action: action, onRowAt: indexPath)
                }
            }
        }
        guard !menuChildren.isEmpty else {
            return nil
        }
        let identifier = message.messageId as NSString
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { (elements) -> UIMenu? in
            UIMenu(title: "", children: menuChildren)
        }
    }
    
    private func previewForContextMenu(with configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let identifier = configuration.identifier as? NSString else {
            return nil
        }
        let messageId = identifier as String
        guard let indexPath = dataSource.indexPath(where: { $0.messageId == messageId }), let cell = tableView.cellForRow(at: indexPath) as? MessageCell, cell.window != nil, let viewModel = dataSource.viewModel(for: indexPath) else {
            return nil
        }
        let param = UIPreviewParameters()
        param.backgroundColor = .clear
        
        if let viewModel = viewModel as? StickerMessageViewModel {
            param.visiblePath = UIBezierPath(roundedRect: viewModel.contentFrame,
                                             cornerRadius: StickerMessageCell.contentCornerRadius)
        } else if let viewModel = viewModel as? AppButtonGroupMessageViewModel {
            param.visiblePath = UIBezierPath(roundedRect: viewModel.contentFrame,
                                             cornerRadius: AppButtonView.cornerRadius)
        } else if let viewModel = viewModel as? AppCardV1MessageViewModel {
            param.visiblePath = UIBezierPath(roundedRect: viewModel.previewFrame,
                                             cornerRadius: AppButtonView.cornerRadius)
        } else {
            if viewModel.style.contains(.received) {
                if viewModel.style.contains(.tail) {
                    param.visiblePath = BubblePath.leftWithTail(frame: viewModel.backgroundImageFrame)
                } else {
                    param.visiblePath = BubblePath.left(frame: viewModel.backgroundImageFrame)
                }
            } else {
                if viewModel.style.contains(.tail) {
                    param.visiblePath = BubblePath.rightWithTail(frame: viewModel.backgroundImageFrame)
                } else {
                    param.visiblePath = BubblePath.right(frame: viewModel.backgroundImageFrame)
                }
            }
        }
        
        return UITargetedPreview(view: cell.messageContentView, parameters: param)
    }
    
}

// MARK: - Embedded classes
extension ConversationViewController {
    
    private enum SelectionAvailability {
        case available
        case visibleButUnavailable(reason: String)
        case invisible
    }
    
    struct Position: CustomDebugStringConvertible {
        let messageId: String
        let offset: CGFloat
        
        var debugDescription: String {
            return "{\(messageId), \(offset)}"
        }
    }
    
    class ResizeInputWrapperGestureRecognizer: UIPanGestureRecognizer {
        
        var hasMovedInputWrapperDuringChangedState = false
        var inputWrapperHeightWhenBegan: CGFloat = 0
        
        override func reset() {
            super.reset()
            hasMovedInputWrapperDuringChangedState = false
        }
        
    }
    
    class FastReplyGestureRecognizer: UIPanGestureRecognizer {
        
        weak var cell: MessageCell?
        
    }
    
}
