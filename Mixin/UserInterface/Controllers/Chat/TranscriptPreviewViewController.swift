import UIKit
import MixinServices

class TranscriptPreviewViewController: FullscreenPopupViewController {
    
    let transcriptMessage: MessageItem
    let backgroundView = UIVisualEffectView(effect: .prominentBlur)
    let tableView = ConversationTableView()
    
    private let factory: ViewModelFactory
    private let queue: Queue
    
    private lazy var audioManager: TranscriptAudioMessagePlayingManager = {
        let manager = TranscriptAudioMessagePlayingManager(transcriptId: transcriptMessage.messageId)
        manager.delegate = self
        return manager
    }()
    
    private var childMessages: [TranscriptMessage] = []
    private var dates: [String] = []
    private var viewModels: [String: [MessageViewModel]] = [:]
    private var indexPathToFlashAfterAnimationFinished: IndexPath?
    private var didPlayAudioMessage = false
    
    init(transcriptMessage: MessageItem) {
        self.transcriptMessage = transcriptMessage
        self.factory = ViewModelFactory()
        self.queue = Queue(label: "one.mixin.messenger.TranscriptPreviewViewController-\(transcriptMessage.messageId)")
        let nib = R.nib.fullscreenPopupView
        super.init(nibName: nib.name, bundle: nib.bundle)
        factory.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageControlView.style = .light
        
        contentView.backgroundColorIgnoringSystemSettings = .clear
        contentView.insertSubview(backgroundView, belowSubview: pageControlView)
        backgroundView.snp.makeEdgesEqualToSuperview()
        
        backgroundView.contentView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview().priority(.high)
            make.top.greaterThanOrEqualToSuperview().offset(20)
        }
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapRecognizer.delegate = self
        tableView.addGestureRecognizer(tapRecognizer)
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateAttachmentProgress(_:)),
                           name: AttachmentLoadingJob.progressNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(mediaStatusDidUpdate(_:)),
                           name: TranscriptMessageDAO.mediaStatusDidUpdateNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(conversationDidChange(_:)),
                           name: MixinServices.conversationDidChangeNotification,
                           object: nil)
        
        let layoutWidth = AppDelegate.current.mainWindow.bounds.width
        let transcriptId = transcriptMessage.messageId
        queue.async { [weak self] in
            let items = TranscriptMessageDAO.shared.messageItems(transcriptId: transcriptId)
            let children = items.compactMap { item in
                TranscriptMessage(transcriptId: transcriptId, mediaUrl: item.mediaUrl, thumbImage: item.thumbImage, messageItem: item)
            }
            for item in items where item.category == MessageCategory.SIGNAL_STICKER.rawValue {
                if item.stickerId == nil {
                    item.category = MessageCategory.SIGNAL_TEXT.rawValue
                    item.content = R.string.localizable.notification_content_sticker()
                }
            }
            guard let (dates, viewModels) = self?.factory.viewModels(with: items, fits: layoutWidth) else {
                return
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.childMessages = children
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if view.safeAreaInsets.bottom < 20 {
            tableView.contentInset.bottom = 20
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    override func dismissAsChild(animated: Bool, completion: (() -> Void)? = nil) {
        if didPlayAudioMessage {
            audioManager.stop()
        }
        super.dismissAsChild(animated: animated, completion: completion)
    }
    
    override func moreAction(_ sender: Any) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.chat_message_menu_forward(), style: .default, handler: { _ in
            let isTranscriptAttachmentDownloaded = self.transcriptMessage.mediaStatus == MediaStatus.DONE.rawValue
                || self.transcriptMessage.mediaStatus == MediaStatus.READ.rawValue
            if isTranscriptAttachmentDownloaded {
                let picker = MessageReceiverViewController.instance(content: .messages([self.transcriptMessage]))
                self.navigationController?.pushViewController(picker, animated: true)
            } else {
                let alert = UIAlertController(title: R.string.localizable.chat_transcript_forward_invalid_media_status(), message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_ok(), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func tapAction(_ recognizer: UIGestureRecognizer) {
        if UIMenuController.shared.isMenuVisible {
            UIMenuController.shared.setMenuVisible(false, animated: true)
            return
        }
        let tappedIndexPath = tableView.indexPathForRow(at: recognizer.location(in: tableView))
        let tappedViewModel: MessageViewModel? = {
            if let indexPath = tappedIndexPath {
                return viewModel(at: indexPath)
            } else {
                return nil
            }
        }()
        if let indexPath = tappedIndexPath, let cell = tableView.cellForRow(at: indexPath) as? MessageCell, cell.contentFrame.contains(recognizer.location(in: cell)), let viewModel = tappedViewModel {
            let message = viewModel.message
            let isImageOrVideo = message.category.hasSuffix("_IMAGE") || message.category.hasSuffix("_VIDEO")
            let mediaStatusIsReady = message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue
            if let quoteMessageId = viewModel.message.quoteMessageId,
               !quoteMessageId.isEmpty,
               let quote = cell.quotedMessageViewIfLoaded,
               quote.bounds.contains(recognizer.location(in: quote)),
               let indexPath = self.indexPath(where: { $0.messageId == quoteMessageId })
            {
                tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                if let indexPaths = tableView.indexPathsForVisibleRows, indexPaths.contains(indexPath) {
                    flashCellBackground(at: indexPath)
                } else {
                    indexPathToFlashAfterAnimationFinished = indexPath
                }
            } else if message.category.hasSuffix("_AUDIO"), message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue {
                if audioManager.playingMessage?.messageId == message.messageId, audioManager.player?.status == .playing {
                    audioManager.pause()
                } else if CallService.shared.hasCall {
                    alert(R.string.localizable.chat_voice_record_on_call())
                } else {
                    (cell as? AudioMessageCell)?.updateUnreadStyle()
                    audioManager.play(message: message)
                    didPlayAudioMessage = true
                }
            } else if (isImageOrVideo && mediaStatusIsReady) || message.category.hasSuffix("_LIVE"),
                      let galleryViewController = UIApplication.homeContainerViewController?.galleryViewController,
                      let cell = cell as? PhotoRepresentableMessageCell
            {
                var items: [GalleryItem] = []
                for date in dates {
                    guard let viewModels = self.viewModels[date] else {
                        continue
                    }
                    let new = viewModels.compactMap(GalleryItem.init)
                    items.append(contentsOf: new)
                }
                if let index = items.firstIndex(where: { $0.messageId == message.messageId }) {
                    galleryViewController.conversationId = nil
                    galleryViewController.show(items: items, index: index, from: cell)
                }
            } else if message.category.hasSuffix("_DATA"), let viewModel = viewModel as? DataMessageViewModel, let cell = cell as? DataMessageCell {
                if viewModel.mediaStatus == MediaStatus.DONE.rawValue || viewModel.mediaStatus == MediaStatus.READ.rawValue {
                    if let filename = message.mediaUrl {
                        let url = AttachmentContainer.url(transcriptId: transcriptMessage.messageId, filename: filename)
                        if FileManager.default.fileExists(atPath: url.path) {
                            let controller = UIDocumentInteractionController(url: url)
                            controller.delegate = self
                            if !controller.presentPreview(animated: true) {
                                controller.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
                            }
                        }
                    }
                } else {
                    attachmentLoadingCellDidSelectNetworkOperation(cell)
                }
            } else if message.category.hasSuffix("_CONTACT"), let shareUserId = message.sharedUserId {
                if shareUserId == myUserId {
                    guard let account = LoginManager.shared.account else {
                        return
                    }
                    let user = UserItem.createUser(from: account)
                    let vc = UserProfileViewController(user: user)
                    present(vc, animated: true, completion: nil)
                } else if let user = UserDAO.shared.getUser(userId: shareUserId), user.isCreatedByMessenger {
                    let vc = UserProfileViewController(user: user)
                    present(vc, animated: true, completion: nil)
                }
            } else if message.category.hasSuffix("_POST") {
                let message = Message.createMessage(message: message)
                PostWebViewController.presentInstance(message: message, asChildOf: self)
            } else if message.category.hasSuffix("_LOCATION"), let location = message.location {
                let vc = LocationPreviewViewController(location: location)
                let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_menu_location())
                navigationController?.pushViewController(container, animated: true)
            } else if message.category == MessageCategory.APP_CARD.rawValue, let appCard = message.appCard {
                if let appId = appCard.appId, !appId.isEmpty {
                    DispatchQueue.global().async { [weak self] in
                        var app = AppDAO.shared.getApp(appId: appId)
                        if app == nil {
                            if case let .success(response) = UserAPI.showUser(userId: appId) {
                                UserDAO.shared.updateUsers(users: [response])
                                app = response.app
                            }
                        }
                        guard let self = self, let app = app else {
                            return
                        }
                        DispatchQueue.main.async {
                            guard !UrlWindow.checkUrl(url: appCard.action) else {
                                return
                            }
                            let context = MixinWebViewController.Context(conversationId: "", url: appCard.action, app: app)
                            MixinWebViewController.presentInstance(with: context, asChildOf: self)
                        }
                    }
                }
            } else if message.category == MessageCategory.SIGNAL_TRANSCRIPT.rawValue {
                let vc = TranscriptPreviewViewController(transcriptMessage: message)
                vc.presentAsChild(of: self, completion: nil)
            }
        }
    }
    
    @objc private func conversationDidChange(_ sender: Notification) {
        guard
            let change = sender.object as? ConversationChange,
            case .recallMessage(let messageId) = change.action,
            messageId == transcriptMessage.messageId
        else {
            return
        }
        dismissAsChild(animated: true)
    }
    
}

// MARK: - MessageViewModelFactoryDelegate
extension TranscriptPreviewViewController: MessageViewModelFactoryDelegate {
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, showUsernameForMessageIfNeeded message: MessageItem) -> Bool {
        message.userId != myUserId
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, isMessageForwardedByBot message: MessageItem) -> Bool {
        false
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, updateViewModelForPresentation viewModel: MessageViewModel) {
        if let viewModel = viewModel as? AttachmentLoadingViewModel {
            viewModel.transcriptId = self.transcriptMessage.messageId
        }
    }
    
}

// MARK: - UITableViewDataSource
extension TranscriptPreviewViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModels(at: section)?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = self.viewModel(at: indexPath) else {
            return self.tableView.dequeueReusableCell(withReuseId: .unknown, for: indexPath)
        }
        let cell = self.tableView.dequeueReusableCell(withMessage: viewModel.message, for: indexPath)
        if let cell = cell as? AttachmentLoadingMessageCell {
            cell.attachmentLoadingDelegate = self
        }
        if let cell = cell as? DetailInfoMessageCell {
            cell.delegate = self
        }
        if let cell = cell as? TextMessageCell {
            cell.contentLabel.delegate = self
        }
        if let cell = cell as? AudioMessageCell {
            cell.audioMessagePlayingManager = audioManager
        }
        if let cell = cell as? MessageCell {
            CATransaction.performWithoutAnimation {
                cell.render(viewModel: viewModel)
                cell.layoutIfNeeded()
            }
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        dates.count
    }
    
}

// MARK: - UIScrollViewDelegate
extension TranscriptPreviewViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if let indexPath = indexPathToFlashAfterAnimationFinished {
            flashCellBackground(at: indexPath)
            self.indexPathToFlashAfterAnimationFinished = nil
        }
    }
    
}

// MARK: - UITableViewDelegate
extension TranscriptPreviewViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let viewModel = self.viewModel(at: indexPath) as? AttachmentLoadingViewModel, viewModel.automaticallyLoadsAttachment {
            viewModel.beginAttachmentLoading(isTriggeredByUser: false)
        }
        if let cell = cell as? AttachmentLoadingMessageCell {
            cell.updateOperationButtonStyle()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let viewModel = self.viewModel(at: indexPath) else {
            return 1
        }
        if viewModel.cellHeight.isNaN || viewModel.cellHeight < 1 {
            return 1
        } else {
            return viewModel.cellHeight
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return ConversationDateHeaderView.height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ConversationTableView.ReuseId.header.rawValue) as! ConversationDateHeaderView
        let date = dates[section]
        header.label.text = DateFormatter.yyyymmdd.date(from: date)?.chatTimeAgo()
        return header
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        nil
    }
    
}

// MARK: - AttachmentLoadingMessageCellDelegate
extension TranscriptPreviewViewController: AttachmentLoadingMessageCellDelegate {
    
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: UITableViewCell & AttachmentLoadingMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let viewModel = self.viewModel(at: indexPath) as? MessageViewModel & AttachmentLoadingViewModel else {
            return
        }
        switch viewModel.operationButtonStyle {
        case .download, .upload:
            viewModel.beginAttachmentLoading(isTriggeredByUser: true)
            viewModel.operationButtonStyle = .busy(progress: 0)
        case .busy:
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
            viewModel.operationButtonStyle = .download
        case .expired, .finished:
            break
        }
        cell.updateOperationButtonStyle()
    }
    
}

// MARK: - UIDocumentInteractionControllerDelegate
extension TranscriptPreviewViewController: UIDocumentInteractionControllerDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        self
    }
    
}

// MARK: - DetailInfoMessageCellDelegate
extension TranscriptPreviewViewController: DetailInfoMessageCellDelegate {
    
    func detailInfoMessageCellDidSelectFullname(_ cell: DetailInfoMessageCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let message = self.viewModel(at: indexPath)?.message,
            let user = UserDAO.shared.getUser(userId: message.userId)
        else {
            return
        }
        let vc = UserProfileViewController(user: user)
        present(vc, animated: true, completion: nil)
    }
    
}

// MARK: - CoreTextLabelDelegate
extension TranscriptPreviewViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        guard !openUrlOutsideApplication(url) else {
            return
        }
        open(url: url)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        guard url.scheme != MixinInternalURL.scheme else {
            return
        }
        let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_OPEN_URL, style: .default, handler: { [weak self](_) in
            self?.open(url: url)
        }))
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_MENU_COPY, style: .default, handler: { (_) in
            UIPasteboard.general.string = url.absoluteString
            showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
            
        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension TranscriptPreviewViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let view = touch.view as? TextMessageLabel {
            return !view.canResponseTouch(at: touch.location(in: view))
        } else {
            return true
        }
    }
    
}

// MARK: - TranscriptAudioMessagePlayingManagerDelegate
extension TranscriptPreviewViewController: TranscriptAudioMessagePlayingManagerDelegate {
    
    func transcriptAudioMessagePlayingManager(_ manager: TranscriptAudioMessagePlayingManager, playableMessageNextTo message: MessageItem) -> MessageItem? {
        guard var indexPath = self.indexPath(where: { $0.messageId == message.messageId }) else {
            return nil
        }
        indexPath.row += 1
        if let message = self.viewModel(at: indexPath)?.message, message.category == MessageCategory.SIGNAL_AUDIO.rawValue {
            return message
        } else {
            return nil
        }
    }
    
}

// MARK: - Attachment Callbacks
extension TranscriptPreviewViewController {
    
    @objc private func updateAttachmentProgress(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let messageId = userInfo[AttachmentLoadingJob.UserInfoKey.messageId] as? String,
            let progress = userInfo[AttachmentLoadingJob.UserInfoKey.progress] as? Double,
            let indexPath = self.indexPath(where: { $0.messageId == messageId })
        else {
            return
        }
        if let viewModel = self.viewModel(at: indexPath) as? MessageViewModel & AttachmentLoadingViewModel {
            viewModel.progress = progress
        }
        if let cell = tableView.cellForRow(at: indexPath) as? AttachmentLoadingMessageCell {
            cell.updateProgress()
        }
    }
    
    @objc private func mediaStatusDidUpdate(_ notification: Notification) {
        guard
            let transcriptId = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.transcriptId] as? String,
            let messageId = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.messageId] as? String,
            let mediaStatus = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.mediaStatus] as? MediaStatus,
            transcriptId == self.transcriptMessage.messageId,
            let child = childMessages.first(where: { $0.messageId == messageId })
        else {
            return
        }
        let mediaUrl = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.mediaUrl] as? String
        child.mediaStatus = mediaStatus.rawValue
        if let mediaUrl = mediaUrl {
            child.mediaUrl = mediaUrl
        }
        if let indexPath = self.indexPath(where: { $0.messageId == messageId }), let viewModel = self.viewModel(at: indexPath) {
            if let viewModel = viewModel as? AttachmentLoadingViewModel {
                viewModel.mediaStatus = mediaStatus.rawValue
            }
            if let viewModel = viewModel as? PhotoRepresentableMessageViewModel {
                viewModel.update(mediaUrl: child.mediaUrl,
                                 mediaSize: viewModel.message.mediaSize,
                                 mediaDuration: viewModel.message.mediaDuration)
            } else if viewModel is AudioMessageViewModel || viewModel is DataMessageViewModel {
                if let mediaUrl = mediaUrl {
                    viewModel.message.mediaUrl = mediaUrl
                }
            }
            if let cell = tableView.cellForRow(at: indexPath) as? MessageCell {
                cell.render(viewModel: viewModel)
            }
        }
    }
    
}

// MARK: - Private works
extension TranscriptPreviewViewController {
    
    private final class ViewModelFactory: MessageViewModelFactory {
        
        override func style(
            forIndex index: Int,
            isFirstMessage: Bool,
            isLastMessage: Bool,
            messageAtIndex: (Int) -> MessageItem
        ) -> MessageViewModel.Style {
            var style = super.style(forIndex: index,
                                    isFirstMessage: isFirstMessage,
                                    isLastMessage: isLastMessage,
                                    messageAtIndex: messageAtIndex)
            style.insert(.noStatus)
            return style
        }
        
    }
    
    private func viewModels(at section: Int) -> [MessageViewModel]? {
        guard section < dates.count else {
            return nil
        }
        let date = dates[section]
        return viewModels[date]
    }
    
    private func viewModel(at indexPath: IndexPath) -> MessageViewModel? {
        guard let viewModels = viewModels(at: indexPath.section), indexPath.row < viewModels.count else {
            return nil
        }
        return viewModels[indexPath.row]
    }
    
    private func indexPath(where predicate: (MessageItem) -> Bool) -> IndexPath? {
        for (section, date) in dates.enumerated() {
            let viewModels = viewModels[date]!
            for (row, viewModel) in viewModels.enumerated() {
                if predicate(viewModel.message) {
                    return IndexPath(row: row, section: section)
                }
            }
        }
        return nil
    }
    
    private func flashCellBackground(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? DetailInfoMessageCell else {
            return
        }
        cell.updateAppearance(highlight: true, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            cell.updateAppearance(highlight: false, animated: true)
        })
    }
    
    private func open(url: URL) {
        guard !UrlWindow.checkUrl(url: url) else {
            return
        }
        MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url), asChildOf: self)
    }
    
}
