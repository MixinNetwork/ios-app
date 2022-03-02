import UIKit
import MixinServices

final class TranscriptPreviewViewController: StaticMessagesViewController {
    
    let transcriptMessage: MessageItem
    
    private var childMessages: [TranscriptMessage] = []
    
    init(transcriptMessage: MessageItem) {
        self.transcriptMessage = transcriptMessage
        let audioManager = TranscriptAudioMessagePlayingManager(transcriptId: transcriptMessage.messageId)
        super.init(conversationId: transcriptMessage.conversationId, audioManager: audioManager)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        factory.delegate = self
        titleLabel.text = R.string.localizable.chat_transcript()
        reloadData()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mediaStatusDidUpdate(_:)),
                                               name: TranscriptMessageDAO.mediaStatusDidUpdateNotification,
                                               object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        reloadData()
    }
    
    override func attachmentURL(withFilename filename: String) -> URL? {
        return AttachmentContainer.url(transcriptId: transcriptMessage.messageId, filename: filename)
    }
    
    override func contextMenuActions(for viewModel: MessageViewModel) -> [UIAction]? {
        if viewModel.message.category.hasSuffix("_STICKER"), let stickerId = viewModel.message.stickerId {
            var actions = super.contextMenuActions(for: viewModel) ?? []
            let addStickerAction = UIAction(title: R.string.localizable.chat_message_sticker(), image: R.image.conversation.ic_action_add_to_sticker()) { _ in
                self.addSticker(stickerId: stickerId)
            }
            actions.append(addStickerAction)
            return actions
        } else {
            return super.contextMenuActions(for: viewModel)
        }
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
            viewModel.transcriptId = transcriptMessage.messageId
        }
    }
    
}

// MARK: - Callbacks
extension TranscriptPreviewViewController {
    
    override func conversationDidChange(_ sender: Notification) {
        super.conversationDidChange(sender)
        guard
            let change = sender.object as? ConversationChange,
            case .recallMessage(let messageId) = change.action,
            messageId == transcriptMessage.messageId
        else {
            return
        }
        dismissAsChild(completion: nil)
    }
    
    @objc private func mediaStatusDidUpdate(_ notification: Notification) {
        guard
            let transcriptId = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.transcriptId] as? String,
            let messageId = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.messageId] as? String,
            let mediaStatus = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.mediaStatus] as? MediaStatus,
            transcriptId == transcriptMessage.messageId,
            let child = childMessages.first(where: { $0.messageId == messageId })
        else {
            return
        }
        let mediaUrl = notification.userInfo?[TranscriptMessageDAO.UserInfoKey.mediaUrl] as? String
        child.mediaStatus = mediaStatus.rawValue
        if let mediaUrl = mediaUrl {
            child.mediaUrl = mediaUrl
        }
        if let indexPath = self.indexPath(where: { $0.messageId == messageId }), let viewModel = viewModel(at: indexPath) {
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

// MARK: - Helper
extension TranscriptPreviewViewController {
    
    private func addSticker(stickerId: String) {
        StickerAPI.addSticker(stickerId: stickerId, completion: { (result) in
            switch result {
            case let .success(sticker):
                DispatchQueue.global().async {
                    StickerDAO.shared.insertOrUpdateFavoriteSticker(sticker: sticker)
                    showAutoHiddenHud(style: .notification, text: Localized.TOAST_ADDED)
                }
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }
    
    private func reloadData() {
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            let transcriptId = self.transcriptMessage.messageId
            let items = TranscriptMessageDAO.shared.messageItems(transcriptId: transcriptId)
            let children = items.compactMap { item in
                TranscriptMessage(transcriptId: transcriptId, mediaUrl: item.mediaUrl, thumbImage: item.thumbImage, messageItem: item)
            }
            let (dates, viewModels) = self.categorizedViewModels(with: items, fits: self.layoutWidth)
            DispatchQueue.main.async {
                self.childMessages = children
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
        }
    }
    
}
