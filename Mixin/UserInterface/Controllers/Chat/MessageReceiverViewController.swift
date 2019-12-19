import UIKit
import AVFoundation

class MessageReceiverViewController: PeerViewController<[MessageReceiver], CheckmarkPeerCell, MessageReceiverSearchResult> {
    
    private var messageContent: MessageContent!
    private var selections = [MessageReceiver]() {
        didSet {
            container?.rightButton.isEnabled = selections.count > 0
        }
    }
    
    class func instance(content: MessageContent) -> UIViewController {
        let vc = MessageReceiverViewController()
        vc.messageContent = content
        return ContainerViewController.instance(viewController: vc, title: Localized.ACTION_SHARE_TO)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsMultipleSelection = true
    }
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [[MessageReceiver]]) {
        let users = users.map(MessageReceiver.init)
        let conversations = ConversationDAO.shared.conversationList()
            .compactMap(MessageReceiver.init)
        let titles = [R.string.localizable.chat_forward_chats(),
                      R.string.localizable.chat_forward_contacts()]
        return (titles, [conversations, users])
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let receivers = self.models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let uniqueReceivers = Set(receivers.flatMap({ $0 }))
            let searchResults = uniqueReceivers
                .filter { $0.matches(lowercasedKeyword: keyword) }
                .map { MessageReceiverSearchResult(receiver: $0, keyword: keyword) }
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    return
                }
                weakSelf.searchingKeyword = keyword
                weakSelf.searchResults = searchResults
                weakSelf.tableView.reloadData()
                weakSelf.reloadTableViewSelections()
            }
        }
        queue.addOperation(op)
    }
    
    override func configure(cell: CheckmarkPeerCell, at indexPath: IndexPath) {
        if isSearching {
            cell.render(result: searchResults[indexPath.row])
        } else {
            cell.render(receiver: models[indexPath.section][indexPath.row])
        }
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        if isSearching {
            for (index, result) in searchResults.enumerated() {
                guard selections.contains(result.receiver) else {
                    continue
                }
                let indexPath = IndexPath(row: index, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        } else {
            for section in 0..<models.count {
                for indexPath in receiverIndexPathsWhichMatchSelections(of: section) {
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? 1 : models.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : models[section].count
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let receiver = messageReceiver(at: indexPath)
        selections.append(receiver)
        if !isSearching {
            let counterSection = indexPath.section == 0 ? 1 : 0
            for indexPath in receiverIndexPathsWhichMatchSelections(of: counterSection) {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let receiver = messageReceiver(at: indexPath)
        if let idx = selections.firstIndex(of: receiver) {
            selections.remove(at: idx)
        }
        if !isSearching {
            let counterSection = indexPath.section == 0 ? 1 : 0
            let enumeratedReceivers = models[counterSection].enumerated()
            if let (row, _) = enumeratedReceivers.first(where: { $1.conversationId == receiver.conversationId }) {
                let indexPath = IndexPath(row: row, section: counterSection)
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
    }
    
}

extension MessageReceiverViewController: ContainerViewControllerDelegate {
    
    func textBarRightButton() -> String? {
        return R.string.localizable.action_send()
    }
    
    func barRightButtonTappedAction() {
        container?.rightButton.isBusy = true
        let content = self.messageContent!
        let selections = self.selections
        DispatchQueue.global().async { [weak self] in
            for receiver in selections {
                guard let message = MessageReceiverViewController.makeMessage(content: content, to: receiver.conversationId) else {
                    continue
                }
                switch receiver.item {
                case .group:
                    SendMessageService.shared.sendMessage(message: message, ownerUser: nil, isGroupMessage: true)
                case .user(let user):
                    SendMessageService.shared.sendMessage(message: message, ownerUser: user, isGroupMessage: false)
                }
            }
            DispatchQueue.main.async {
                self?.popToConversationWithLastSelection()
            }
        }
    }
    
}

extension MessageReceiverViewController {
    
    private func messageReceiver(at indexPath: IndexPath) -> MessageReceiver {
        if isSearching {
            return searchResults[indexPath.row].receiver
        } else {
            return models[indexPath.section][indexPath.row]
        }
    }
    
    private func receiverIndexPathsWhichMatchSelections(of section: Int) -> [IndexPath] {
        assert(!isSearching)
        var indexPaths = [IndexPath]()
        for (row, receiver) in models[section].enumerated() where selections.contains(receiver) {
            indexPaths.append(IndexPath(row: row, section: section))
        }
        return indexPaths
    }
    
    private func popToConversationWithLastSelection() {
        if let receiver = selections.last {
            let vc: ConversationViewController
            switch receiver.item {
            case .group(let conversation):
                vc = ConversationViewController.instance(conversation: conversation)
            case .user(let user):
                vc = ConversationViewController.instance(ownerUser: user)
            }
            navigationController?.pushViewController(withBackRoot: vc)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
}

extension MessageReceiverViewController {
    
    enum MessageContent {
        case message(MessageItem)
        case contact(String)
        case photo(UIImage)
        case text(String)
        case video(URL)
    }
    
    static func makeMessage(content: MessageContent, to conversationId: String) -> Message? {
        switch content {
        case .message(let message):
            return makeMessage(message: message, to: conversationId)
        case .contact(let userId):
            return makeMessage(userId: userId, to: conversationId)
        case .photo(let image):
            return makeMessage(image: image, to: conversationId)
        case .text(let text):
            return makeMessage(text: text, to: conversationId)
        case .video(let url):
            return makeMessage(videoUrl: url, to: conversationId)
        }
    }
    
    // Copy media file in case of deletion or recalling
    static func mediaUrl(from message: MessageItem, with newMessageId: String) -> String? {
        guard let category = AttachmentContainer.Category(messageCategory: message.category), let mediaUrl = message.mediaUrl else {
            return message.mediaUrl
        }
        
        let fromUrl = AttachmentContainer.url(for: category, filename: mediaUrl)
        guard FileManager.default.fileExists(atPath: fromUrl.path) else {
            return message.mediaUrl
        }
        let filename = newMessageId + "." + fromUrl.pathExtension
        let toUrl = AttachmentContainer.url(for: category, filename: filename)
        try? FileManager.default.copyItem(at: fromUrl, to: toUrl)
        
        if message.category.hasSuffix("_VIDEO") {
            let fromThumbnailUrl = AttachmentContainer.url(for: .videos, filename: mediaUrl.substring(endChar: ".") + ExtensionName.jpeg.withDot)
            let targetThumbnailUrl = AttachmentContainer.url(for: .videos, filename: newMessageId + ExtensionName.jpeg.withDot)
            try? FileManager.default.copyItem(at: fromThumbnailUrl, to: targetThumbnailUrl)
        }
        
        return toUrl.lastPathComponent
    }
    
    static func makeMessage(message: MessageItem, to conversationId: String) -> Message? {
        var newMessage = Message.createMessage(category: message.category,
                                               conversationId: conversationId,
                                               userId: myUserId)
        if message.category.hasSuffix("_TEXT") {
            newMessage.content = message.content
        } else if message.category.hasSuffix("_IMAGE") {
            newMessage.thumbImage = message.thumbImage
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaWidth = message.mediaWidth
            newMessage.mediaHeight = message.mediaHeight
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = mediaUrl(from: message, with: newMessage.messageId)
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_DATA") {
            newMessage.name = message.name
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = mediaUrl(from: message, with: newMessage.messageId)
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_AUDIO") {
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = mediaUrl(from: message, with: newMessage.messageId)
            newMessage.mediaWaveform = message.mediaWaveform
            newMessage.mediaDuration = message.mediaDuration
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
        } else if message.category.hasSuffix("_VIDEO") {
            newMessage.thumbImage = message.thumbImage
            newMessage.mediaSize = message.mediaSize
            newMessage.mediaWidth = message.mediaWidth
            newMessage.mediaHeight = message.mediaHeight
            newMessage.mediaMimeType = message.mediaMimeType
            newMessage.mediaUrl = mediaUrl(from: message, with: newMessage.messageId)
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
            newMessage.mediaDuration = message.mediaDuration
        } else if message.category.hasSuffix("_STICKER") {
            newMessage.mediaUrl = message.mediaUrl
            newMessage.stickerId = message.stickerId
            newMessage.mediaStatus = MediaStatus.PENDING.rawValue
            let transferData = TransferStickerData(stickerId: message.stickerId, name: nil, albumId: nil)
            newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        } else if message.category.hasSuffix("_CONTACT") {
            guard let sharedUserId = message.sharedUserId else {
                return nil
            }
            newMessage.sharedUserId = sharedUserId
            let transferData = TransferContactData(userId: sharedUserId)
            newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        } else if message.category.hasSuffix("_LIVE"), let width = message.mediaWidth, let height = message.mediaHeight, let mediaUrl = message.mediaUrl, let thumbUrl = message.thumbUrl {
            newMessage.mediaWidth = message.mediaWidth
            newMessage.mediaHeight = message.mediaHeight
            newMessage.mediaUrl = message.mediaUrl
            newMessage.thumbUrl = message.thumbUrl
            let liveData = TransferLiveData(width: width, height: height, thumbUrl: thumbUrl, url: mediaUrl)
            newMessage.content = try! JSONEncoder.default.encode(liveData).base64EncodedString()
        } else {
            return nil
        }
        return newMessage
    }
    
    static func makeMessage(userId: String, to conversationId: String) -> Message? {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue,
                                            conversationId: conversationId,
                                            userId: myUserId)
        message.sharedUserId = userId
        let transferData = TransferContactData(userId: userId)
        message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
        return message
    }
    
    static func makeMessage(image: UIImage, to conversationId: String) -> Message? {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue,
                                            conversationId: conversationId,
                                            userId: myUserId)
        let filename = message.messageId + ExtensionName.jpeg.withDot
        let path = AttachmentContainer.url(for: .photos, filename: filename)
        guard image.saveToFile(path: path), FileManager.default.fileSize(path.path) > 0, image.size.width > 0, image.size.height > 0 else {
            showAutoHiddenHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
            return nil
        }
        message.thumbImage = image.base64Thumbnail()
        message.mediaSize = FileManager.default.fileSize(path.path)
        message.mediaWidth = Int(image.size.width)
        message.mediaHeight = Int(image.size.height)
        message.mediaMimeType = "image/jpeg"
        message.mediaUrl = filename
        message.mediaStatus = MediaStatus.PENDING.rawValue
        return message
    }
    
    static func makeMessage(text: String, to conversationId: String) -> Message {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_TEXT.rawValue,
                                            conversationId: conversationId,
                                            userId: myUserId)
        message.content = text
        return message
    }
    
    static func makeMessage(videoUrl: URL, to conversationId: String) -> Message? {
        let asset = AVAsset(url: videoUrl)
        guard asset.duration.isValid, let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        var message = Message.createMessage(category: MessageCategory.SIGNAL_VIDEO.rawValue,
                                            conversationId: conversationId,
                                            userId: myUserId)
        let filename = videoUrl.lastPathComponent.substring(endChar: ".")
        let thumbnailFilename = filename + ExtensionName.jpeg.withDot
        if let thumbnail = UIImage(withFirstFrameOfVideoAtURL: videoUrl) {
            let thumbnailURL = AttachmentContainer.url(for: .videos, filename: thumbnailFilename)
            thumbnail.saveToFile(path: thumbnailURL)
            message.thumbImage = thumbnail.base64Thumbnail()
        } else {
            return nil
        }
        message.mediaDuration = Int64(asset.duration.seconds * millisecondsPerSecond)
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        message.mediaWidth = Int(abs(size.width))
        message.mediaHeight = Int(abs(size.height))
        message.mediaSize = FileManager.default.fileSize(videoUrl.path)
        message.mediaMimeType = FileManager.default.mimeType(ext: videoUrl.pathExtension)
        message.mediaUrl = videoUrl.lastPathComponent
        message.mediaStatus = MediaStatus.PENDING.rawValue
        return message
    }
    
}
