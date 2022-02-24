import UIKit
import MixinServices

class StackedPhotoPreviewViewController: StaticMessagesViewController {
    
    let stackedPhotoMessage: MessageItem
    
    private var photoMessageItems: [MessageItem] = []
    
    private var layoutWidth: CGFloat {
        Queue.main.autoSync {
            AppDelegate.current.mainWindow.bounds.width
        }
    }

    init(stackedPhotoMessage: MessageItem) {
        self.stackedPhotoMessage = stackedPhotoMessage
        let audioManager = TranscriptAudioMessagePlayingManager(transcriptId: stackedPhotoMessage.messageId)
        super.init(conversationId: stackedPhotoMessage.conversationId, audioManager: audioManager)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        factory.delegate = self
        if let messages = stackedPhotoMessage.messageItems {
            photoMessageItems = messages
            titleLabel.text = R.string.localizable.chat_photo_preview_count(messages.count)
        }
        reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        reloadData()
    }
    
    override func contextMenuActions(for viewModel: MessageViewModel) -> [UIAction]? {
        var actions = super.contextMenuActions(for: viewModel) ?? []
        let unpinAction = UIAction(title: R.string.localizable.menu_unpin(), image: R.image.conversation.ic_action_unpin()) { (_) in
                
        }
        actions.append(unpinAction)
        return actions
    }
    
}

// MARK: - MessageViewModelFactoryDelegate
extension StackedPhotoPreviewViewController: MessageViewModelFactoryDelegate {
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, showUsernameForMessageIfNeeded message: MessageItem) -> Bool {
        message.userId != myUserId
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, isMessageForwardedByBot message: MessageItem) -> Bool {
        false
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, updateViewModelForPresentation viewModel: MessageViewModel) {
        
    }
    
}

// MARK: - Callbacks
extension StackedPhotoPreviewViewController {
    
    override func conversationDidChange(_ sender: Notification) {
        super.conversationDidChange(sender)
        guard
            let change = sender.object as? ConversationChange,
            case .recallMessage(let messageId) = change.action,
            messageId == stackedPhotoMessage.messageId
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
            transcriptId == stackedPhotoMessage.messageId,
            let child = photoMessageItems.first(where: { $0.messageId == messageId })
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
extension StackedPhotoPreviewViewController {
    
    private func reloadData() {
        let messages = self.photoMessageItems
        queue.async {
            let (dates, viewModels) = self.categorizedViewModels(with: messages, fits: self.layoutWidth)
            DispatchQueue.main.async {
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
        }
    }
    
}

