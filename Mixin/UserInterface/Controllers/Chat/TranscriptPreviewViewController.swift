import UIKit
import MixinServices

final class TranscriptPreviewViewController: StaticMessagesViewController {
    
    let transcriptMessage: MessageItem
    
    private var childMessages: [TranscriptMessage] = []
    
    init(transcriptMessage: MessageItem) {
        self.transcriptMessage = transcriptMessage
        let audioManager = TranscriptAudioMessagePlayingManager(transcriptId: transcriptMessage.messageId)
        super.init(audioManager: audioManager)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.chat_transcript()
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(conversationDidChange(_:)),
                           name: MixinServices.conversationDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(mediaStatusDidUpdate(_:)),
                           name: MessageDAO.messageMediaStatusDidUpdateNotification,
                           object: nil)
        let transcriptId = transcriptMessage.messageId
        let layoutWidth = AppDelegate.current.mainWindow.bounds.width
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            let items = TranscriptMessageDAO.shared.messageItems(transcriptId: transcriptId)
            let children = items.compactMap { item in
                TranscriptMessage(transcriptId: transcriptId, mediaUrl: item.mediaUrl, thumbImage: item.thumbImage, messageItem: item)
            }
            let (dates, viewModels) = self.categorizedViewModels(with: items, fits: layoutWidth)
            DispatchQueue.main.async {
                self.childMessages = children
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
        }
    }
    
}

// MARK: - Override
extension TranscriptPreviewViewController {
    
    override func attachmentURL(withFilename filename: String) -> URL? {
        return AttachmentContainer.url(transcriptId: transcriptMessage.messageId, filename: filename)
    }
    
    override func messageViewModelFactory(_ factory: MessageViewModelFactory, updateViewModelForPresentation viewModel: MessageViewModel) {
        super.messageViewModelFactory(factory, updateViewModelForPresentation: viewModel)
        if let viewModel = viewModel as? AttachmentLoadingViewModel {
            viewModel.transcriptId = self.transcriptMessage.messageId
        }
    }
    
}

// MARK: - Callbacks
extension TranscriptPreviewViewController {
    
    @objc private func conversationDidChange(_ sender: Notification) {
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
        if let indexPath = indexPath(where: { $0.messageId == messageId }), let viewModel = viewModel(at: indexPath) {
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
