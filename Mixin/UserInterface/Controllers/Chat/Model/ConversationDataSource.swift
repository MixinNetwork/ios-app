import UIKit
import AVKit
import Photos
import SDWebImage
import YYImage
import CoreServices

class ConversationDataSource {
    
    static let didAddMessageOutOfBoundsNotification = Notification.Name("one.mixin.ios.conversation.datasource.add.message.outside.visible.bounds")
    
    let queue = DispatchQueue(label: "one.mixin.ios.conversation.datasource")
    
    var ownerUser: UserItem?
    var firstUnreadMessageId: String?
    weak var tableView: ConversationTableView?
    
    private let windowRect = AppDelegate.current.window.bounds
    private let numberOfMessagesOnPaging = 100
    private let numberOfMessagesOnReloading = 35
    private let me = AccountAPI.shared.account!
    
    private lazy var thumbnailRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = true
        return options
    }()
    
    private(set) var conversation: ConversationItem {
        didSet {
            category = conversation.category == ConversationCategory.CONTACT.rawValue ? .contact : .group
        }
    }
    private(set) var dates = [String]()
    private(set) var loadedMessageIds = Set<String>()
    private(set) var didLoadLatestMessage = false
    private(set) var category: Category
    
    private var highlight: Highlight?
    private var viewModels = [String: [MessageViewModel]]()
    private var didLoadEarliestMessage = false
    private var isLoadingAbove = false
    private var isLoadingBelow = false
    private var canInsertUnreadHint = true
    private var messageProcessingIsCancelled = false
    private var didInitializedData = false
    private var tableViewContentInset: UIEdgeInsets {
        return performSynchronouslyOnMainThread {
            self.tableView?.contentInset ?? .zero
        }
    }
    
    var layoutSize: CGSize {
        return windowRect.inset(by: tableViewContentInset).size
    }
    
    var conversationId: String {
        return conversation.conversationId
    }
    
    var lastIndexPath: IndexPath? {
        let section = dates.count - 1
        guard section >= 0, let rowCount = viewModels(for: section)?.count else {
            return nil
        }
        return IndexPath(row: rowCount - 1, section: section)
    }
    
    // MARK: - Interface
    init(conversation: ConversationItem, highlight: Highlight? = nil, ownerUser: UserItem? = nil) {
        self.conversation = conversation
        self.highlight = highlight
        self.ownerUser = ownerUser
        self.category = conversation.category == ConversationCategory.CONTACT.rawValue ? .contact : .group
    }
    
    func initData(completion: @escaping () -> Void) {
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        reload(completion: completion)
    }
    
    func cancelMessageProcessing() {
        messageProcessingIsCancelled = true
        NotificationCenter.default.removeObserver(self)
    }
    
    func scrollToFirstUnreadMessageOrBottom() {
        guard let tableView = tableView else {
            return
        }
        if didLoadLatestMessage {
            if let firstUnreadMessageId = firstUnreadMessageId, let indexPath = indexPath(where: { $0.messageId == firstUnreadMessageId }) {
                tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                self.firstUnreadMessageId = nil
            } else {
                tableView.scrollToBottom(animated: true)
            }
        } else {
            scrollToBottomAndReload(initialMessageId: firstUnreadMessageId)
        }
    }
    
    func scrollToTopAndReload(initialMessageId: String, completion: (() -> Void)? = nil) {
        guard !self.messageProcessingIsCancelled else {
            return
        }
        didLoadEarliestMessage = true
        didLoadLatestMessage = true
        tableView?.setContentOffset(.zero, animated: true)
        ConversationViewController.positions[conversationId] = nil
        queue.async {
            guard !self.messageProcessingIsCancelled else {
                return
            }
            self.reload(initialMessageId: initialMessageId, animatedReloading: false)
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    func scrollToBottomAndReload(initialMessageId: String? = nil, completion: (() -> Void)? = nil) {
        guard !self.messageProcessingIsCancelled else {
            return
        }
        didLoadEarliestMessage = true
        didLoadLatestMessage = true
        highlight = nil
        ConversationViewController.positions[conversationId] = nil
        queue.async {
            guard !self.messageProcessingIsCancelled else {
                return
            }
            self.reload(initialMessageId: initialMessageId, prepareBeforeReload: {
                self.tableView?.bounds.origin.y = 0
            }, completion: completion, animatedReloading: true)
        }
    }
    
    func loadMoreAboveIfNeeded() {
        guard !isLoadingAbove, !didLoadEarliestMessage else {
            return
        }
        isLoadingAbove = true
        let requiredCount = self.numberOfMessagesOnPaging
        let conversationId = self.conversationId
        let layoutWidth = self.layoutSize.width
        queue.async {
            guard !self.messageProcessingIsCancelled, let firstDate = self.dates.first, let location = self.viewModels[firstDate]?.first?.message else {
                return
            }
            var messages = MessageDAO.shared.getMessages(conversationId: conversationId, aboveMessage: location, count: requiredCount)
            let didLoadEarliestMessage = messages.count < requiredCount
            self.didLoadEarliestMessage = didLoadEarliestMessage
            let shouldInsertEncryptionHint = self.canInsertEncryptionHint && didLoadEarliestMessage
            messages = messages.filter{ !self.loadedMessageIds.contains($0.messageId) }
            self.loadedMessageIds.formUnion(messages.map({ $0.messageId }))
            var (dates, viewModels) = self.viewModels(with: messages, fits: layoutWidth)
            if shouldInsertEncryptionHint {
                let hint = MessageItem.encryptionHintMessage(conversationId: conversationId)
                messages.insert(hint, at: 0)
                let encryptionHintViewModel = self.viewModel(withMessage: hint, style: .bottomSeparator, fits: layoutWidth)
                if let firstDate = dates.first {
                    viewModels[firstDate]?.insert(encryptionHintViewModel, at: 0)
                } else if let firstDate = self.dates.first {
                    dates = [firstDate]
                    viewModels[firstDate] = [encryptionHintViewModel]
                }
            }
            let bottomDistance = DispatchQueue.main.sync {
                self.tableView?.bottomDistance ?? 0
            }
            if let lastDate = dates.last, let viewModelsBeforeInsertion = self.viewModels[lastDate] {
                let messagesBeforeInsertion = Array(viewModelsBeforeInsertion.prefix(2)).map({ $0.message })
                let messagesForTheDate = Array(messages.suffix(2)) + messagesBeforeInsertion
                let styles = Array(0..<messagesForTheDate.count).map{ self.style(forIndex: $0, messages: messagesForTheDate)}
                viewModels[lastDate]?.last?.style = styles[styles.count - messagesBeforeInsertion.count - 1]
                DispatchQueue.main.sync {
                    guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                        return
                    }
                    if let viewModel = self.viewModels[lastDate]?.first {
                        viewModel.style = styles[styles.count - messagesBeforeInsertion.count]
                        if let indexPath = self.indexPath(where: { $0.messageId == viewModel.message.messageId }), let cell = tableView.cellForRow(at: indexPath) as? MessageCell {
                            cell.render(viewModel: viewModel)
                            UIView.performWithoutAnimation {
                                tableView.beginUpdates()
                                tableView.endUpdates()
                            }
                        }
                    }
                }
            }
            DispatchQueue.main.sync {
                guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                    return
                }
                for date in dates.reversed() {
                    let newViewModels = viewModels[date]!
                    if self.viewModels[date] == nil {
                        self.dates.insert(date, at: 0)
                        self.viewModels[date] = newViewModels
                    } else {
                        self.viewModels[date]!.insert(contentsOf: newViewModels, at: 0)
                    }
                }
                tableView.reloadData()
                let y = tableView.contentSize.height - bottomDistance
                tableView.setContentOffsetYSafely(y)
                self.isLoadingAbove = false
            }
        }
    }
    
    func loadMoreBelowIfNeeded() {
        guard !isLoadingBelow, !didLoadLatestMessage else {
            return
        }
        isLoadingBelow = true
        let conversationId = self.conversationId
        let requiredCount = self.numberOfMessagesOnPaging
        let layoutWidth = self.layoutSize.width
        var didLoadLatestMessage = false
        queue.async {
            guard !self.messageProcessingIsCancelled, let lastDate = self.dates.last, let location = self.viewModels[lastDate]?.last?.message else {
                return
            }
            var messages = MessageDAO.shared.getMessages(conversationId: conversationId, belowMessage: location, count: requiredCount)
            didLoadLatestMessage = messages.count < requiredCount
            messages = messages.filter{ !self.loadedMessageIds.contains($0.messageId) }
            self.loadedMessageIds.formUnion(messages.map({ $0.messageId }))
            if self.canInsertUnreadHint, let firstUnreadMessageId = self.firstUnreadMessageId, let index = messages.firstIndex(where: { $0.messageId == firstUnreadMessageId }) {
                let firstUnreadMessage = messages[index]
                let hint = MessageItem.createMessage(category: MessageCategory.EXT_UNREAD.rawValue, conversationId: conversationId, createdAt: firstUnreadMessage.createdAt)
                messages.insert(hint, at: index)
                self.canInsertUnreadHint = false
            }
            let (dates, viewModels) = self.viewModels(with: messages, fits: layoutWidth)
            if let firstDate = dates.first, let messagesBeforeAppend = self.viewModels[firstDate]?.suffix(2).map({ $0.message }) {
                let messagesForTheDate = messagesBeforeAppend + messages.prefix(2)
                let styles = Array(0..<messagesForTheDate.count).map{ self.style(forIndex: $0, messages: messagesForTheDate)}
                viewModels[firstDate]?.first?.style = styles[messagesBeforeAppend.count]
                DispatchQueue.main.sync {
                    guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                        return
                    }
                    if let viewModel = self.viewModels[firstDate]?.last {
                        viewModel.style = styles[messagesBeforeAppend.count - 1]
                        if let indexPath = self.indexPath(where: { $0.messageId == viewModel.message.messageId }), let cell = tableView.cellForRow(at: indexPath) as? MessageCell {
                            cell.render(viewModel: viewModel)
                            tableView.beginUpdates()
                            tableView.endUpdates()
                        }
                    }
                }
            }
            DispatchQueue.main.sync {
                guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                    return
                }
                for date in dates {
                    let newViewModels = viewModels[date]!
                    if self.viewModels[date] == nil {
                        self.dates.append(date)
                        self.viewModels[date] = newViewModels
                    } else {
                        self.viewModels[date]!.append(contentsOf: newViewModels)
                    }
                }
                if !viewModels.isEmpty {
                    tableView.reloadData()
                }
                self.didLoadLatestMessage = didLoadLatestMessage
                self.isLoadingBelow = false
            }
        }
    }
    
    func removeViewModel(at indexPath: IndexPath) -> (didRemoveRow: Bool, didRemoveSection: Bool) {
        var didRemoveRow = false
        var didRemoveSection = false
        let date = dates[indexPath.section]
        if let viewModel = viewModels[date]?.remove(at: indexPath.row) {
            didRemoveRow = true
            loadedMessageIds.remove(viewModel.message.messageId)
        }
        if let viewModels = viewModels[date], viewModels.isEmpty {
            if let index = dates.firstIndex(of: date) {
                didRemoveSection = true
                dates.remove(at: index)
            }
            self.viewModels[date] = nil
        }
        if let viewModels = self.viewModels[date] {
            let indexBeforeDeletedMessage = indexPath.row - 1
            let indexAfterDeletedMessage = indexPath.row
            if indexBeforeDeletedMessage >= 0 {
                let style = self.style(forIndex: indexBeforeDeletedMessage, viewModels: viewModels)
                self.viewModels[date]?[indexBeforeDeletedMessage].style = style
            }
            if indexAfterDeletedMessage < viewModels.count {
                let style = self.style(forIndex: indexAfterDeletedMessage, viewModels: viewModels)
                self.viewModels[date]?[indexAfterDeletedMessage].style = style
            }
        }
        return (didRemoveRow, didRemoveSection)
    }
    
    func viewModels(for section: Int) -> [MessageViewModel]? {
        guard section < dates.count else {
            return nil
        }
        let date = dates[section]
        return viewModels[date]
    }
    
    func viewModel(for indexPath: IndexPath) -> MessageViewModel? {
        guard let viewModels = viewModels(for: indexPath.section), indexPath.row < viewModels.count else {
            return nil
        }
        return viewModels[indexPath.row]
    }
    
    func indexPath(where predicate: (MessageItem) -> Bool) -> IndexPath? {
        return indexPath(ofDates: dates, viewModels: viewModels, where: predicate)
    }
    
}

// MARK: - Callback
extension ConversationDataSource {
    
    @objc func conversationDidChange(_ sender: Notification) {
        guard let change = sender.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case .reload:
            highlight = nil
            ConversationViewController.positions[conversationId] = nil
            reload()
        case .update(let conversation):
            self.conversation = conversation
        case .addMessage(let message):
            addMessage(message)
        case .updateGroupIcon(let iconUrl):
            conversation.iconUrl = iconUrl
        case .updateMessage(let messageId):
            updateMessage(messageId: messageId)
        case .updateMessageStatus(let messageId, let newStatus):
            updateMessageStatus(messageId: messageId, status: newStatus)
        case .updateMediaStatus(let messageId, let mediaStatus):
            updateMessageMediaStatus(messageId: messageId, mediaStatus: mediaStatus)
        case .updateUploadProgress(let messageId, let progress):
            updateMediaProgress(messageId: messageId, progress: progress)
        case .updateDownloadProgress(let messageId, let progress):
            updateMediaProgress(messageId: messageId, progress: progress)
        case .updateMediaContent(let messageId, let message):
            updateMediaContent(messageId: messageId, message: message)
        case .recallMessage(let messageId):
            updateMessage(messageId: messageId)
        case .updateConversation, .startedUpdateConversation:
            break
        }
    }
    
    private func addMessage(_ message: MessageItem) {
        guard !loadedMessageIds.contains(message.messageId) else {
            return
        }
        let messageIsSentByMe = message.userId == me.user_id
        if !messageIsSentByMe && message.status == MessageStatus.DELIVERED.rawValue {
            SendMessageService.shared.sendReadMessages(conversationId: message.conversationId)
        }
        if !didLoadLatestMessage {
            if messageIsSentByMe {
                queue.async {
                    guard !self.messageProcessingIsCancelled else {
                        return
                    }
                    DispatchQueue.main.sync {
                        self.scrollToBottomAndReload()
                    }
                }
            } else {
                NotificationCenter.default.postOnMain(name: ConversationDataSource.didAddMessageOutOfBoundsNotification, object: 1)
            }
        } else {
            loadedMessageIds.insert(message.messageId)
            queue.async {
                guard !self.messageProcessingIsCancelled else {
                    return
                }
                self.addMessageAndDisplay(message: message)
            }
        }
    }
    
    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        guard let indexPath = indexPath(where: { $0.messageId == messageId }), let viewModel = viewModel(for: indexPath) as? DetailInfoMessageViewModel else {
            return
        }
        viewModel.status = status.rawValue
        if let cell = tableView?.cellForRow(at: indexPath) as? DetailInfoMessageCell {
            cell.updateStatusImageView()
        }
    }
    
    private func updateMessageMediaStatus(messageId: String, mediaStatus: MediaStatus) {
        guard let indexPath = indexPath(where: { $0.messageId == messageId }) else {
            return
        }
        let viewModel = self.viewModel(for: indexPath)
        let cell = tableView?.cellForRow(at: indexPath)
        if let viewModel = viewModel as? AttachmentLoadingViewModel {
            viewModel.mediaStatus = mediaStatus.rawValue
            if let cell = cell as? (PhotoRepresentableMessageCell & AttachmentExpirationHintingMessageCell) {
                cell.updateOperationButtonAndExpiredHintLabel()
            } else if let cell = cell as? AttachmentLoadingMessageCell {
                cell.updateOperationButtonStyle()
            }
        }
        if let cell = cell as? AudioMessageCell {
            cell.updateUnreadStyle()
        }
    }
    
    private func updateMediaProgress(messageId: String, progress: Double) {
        guard let indexPath = indexPath(where: { $0.messageId == messageId }), let viewModel = viewModel(for: indexPath) as? MessageViewModel & AttachmentLoadingViewModel else {
            return
        }
        viewModel.progress = progress
        if let cell = tableView?.cellForRow(at: indexPath) as? AttachmentLoadingMessageCell {
            cell.updateProgress()
        }
    }
    
    private func updateMediaContent(messageId: String, message: Message) {
        guard let indexPath = indexPath(where: { $0.messageId == messageId }), let viewModel = viewModel(for: indexPath) as? PhotoRepresentableMessageViewModel else {
            return
        }
        viewModel.update(mediaUrl: message.mediaUrl,
                         mediaSize: message.mediaSize,
                         mediaDuration: message.mediaDuration)
        if let cell = tableView?.cellForRow(at: indexPath) as? PhotoRepresentableMessageCell {
            cell.reloadMedia(viewModel: viewModel)
        }
    }
    
    private func updateMessage(messageId: String) {
        queue.async {
            guard !self.messageProcessingIsCancelled else {
                return
            }
            guard let indexPath = self.indexPath(where: { $0.messageId == messageId }) else {
                return
            }
            guard let message = MessageDAO.shared.getFullMessage(messageId: messageId) else {
                return
            }
            
            if message.status == MessageStatus.DELIVERED.rawValue && message.userId != AccountAPI.shared.accountUserId {
                SendMessageService.shared.sendReadMessages(conversationId: message.conversationId)
            }
            
            DispatchQueue.main.sync {
                guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                    return
                }
                let date = DateFormatter.yyyymmdd.string(from: message.createdAt.toUTCDate())
                if let style = self.viewModels[date]?[indexPath.row].style {
                    let viewModel = self.viewModel(withMessage: message, style: style, fits: self.layoutSize.width)
                    self.viewModels[date]?[indexPath.row] = viewModel
                    tableView.reloadData()
                }
            }
        }
    }
    
}

// MARK: - Send Message
extension ConversationDataSource {
    
    func sendMessage(type: MessageCategory, messageId: String? = nil, quoteMessageId: String? = nil , value: Any) {
        let isGroupMessage = category == .group
        let ownerUser = self.ownerUser
        var message = Message.createMessage(category: type.rawValue, conversationId: conversationId, userId: me.user_id)
        message.quoteMessageId = quoteMessageId
        if let messageId = messageId {
            message.messageId = messageId
        }
        if type == .SIGNAL_TEXT, let text = value as? String {
            message.content = text
            queue.async {
                SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: isGroupMessage)
            }
        } else if type == .SIGNAL_DATA, let url = value as? URL {
            queue.async {
                guard FileManager.default.fileSize(url.path) > 0 else {
                    showAutoHiddenHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
                    return
                }
                let fileExtension = url.pathExtension.lowercased()
                let targetUrl = MixinFile.url(ofChatDirectory: .files, filename: "\(message.messageId).\(fileExtension)")
                do {
                    try FileManager.default.copyItem(at: url, to: targetUrl)
                } catch {
                    showAutoHiddenHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
                    return
                }
                message.name = url.lastPathComponent
                message.mediaSize = FileManager.default.fileSize(targetUrl.path)
                message.mediaMimeType = FileManager.default.mimeType(ext: fileExtension)
                message.mediaUrl = targetUrl.lastPathComponent
                message.mediaStatus = MediaStatus.PENDING.rawValue
                SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: isGroupMessage)
            }
        } else if type == .SIGNAL_VIDEO, let url = value as? URL {
            queue.async {
                let asset = AVAsset(url: url)
                guard asset.duration.isValid, let videoTrack = asset.tracks(withMediaType: .video).first else {
                    showAutoHiddenHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
                    return
                }
                if let thumbnail = UIImage(withFirstFrameOfVideoAtURL: url) {
                    let thumbnailURL = MixinFile.url(ofChatDirectory: .videos, filename: url.lastPathComponent.substring(endChar: ".") + ExtensionName.jpeg.withDot)
                    thumbnail.saveToFile(path: thumbnailURL)
                    message.thumbImage = thumbnail.base64Thumbnail()
                } else {
                    showAutoHiddenHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
                    return
                }
                message.mediaDuration = Int64(asset.duration.seconds * millisecondsPerSecond)
                let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
                message.mediaWidth = Int(abs(size.width))
                message.mediaHeight = Int(abs(size.height))
                message.mediaSize = FileManager.default.fileSize(url.path)
                message.mediaMimeType = FileManager.default.mimeType(ext: url.pathExtension)
                message.mediaUrl = url.lastPathComponent
                message.mediaStatus = MediaStatus.PENDING.rawValue
                SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: isGroupMessage)
            }
        } else if type == .SIGNAL_AUDIO, let value = value as? (tempUrl: URL, metadata: MXNAudioMetadata) {
            queue.async {
                guard FileManager.default.fileSize(value.tempUrl.path) > 0 else {
                    showAutoHiddenHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
                    return
                }
                let url = MixinFile.url(ofChatDirectory: .audios, filename: message.messageId + ExtensionName.ogg.withDot)
                do {
                    try FileManager.default.moveItem(at: value.tempUrl, to: url)
                    message.mediaSize = FileManager.default.fileSize(url.path)
                    message.mediaMimeType = FileManager.default.mimeType(ext: url.pathExtension)
                    message.mediaUrl = url.lastPathComponent
                    message.mediaStatus = MediaStatus.PENDING.rawValue
                    message.mediaWaveform = value.metadata.waveform
                    message.mediaDuration = Int64(value.metadata.duration)
                    SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: isGroupMessage)
                } catch {
                    showAutoHiddenHud(style: .error, text: Localized.TOAST_OPERATION_FAILED)
                }
            }
        } else if type == .SIGNAL_STICKER, let sticker = value as? StickerItem {
            message.mediaStatus = MediaStatus.PENDING.rawValue
            message.mediaUrl = sticker.assetUrl
            message.stickerId = sticker.stickerId
            queue.async {
                UIApplication.logEvent(eventName: "send_sticker", parameters: ["stickerId": sticker.stickerId])
                let albumId = AlbumDAO.shared.getAlbum(stickerId: sticker.stickerId)?.albumId
                let transferData = TransferStickerData(stickerId: sticker.stickerId, name: sticker.name, albumId: albumId)
                message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
                SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: isGroupMessage)
            }
        }
    }
    
    func send(image: GiphyImage, thumbnail: UIImage?) {
        let conversationId = self.conversationId
        let ownerUser = self.ownerUser
        let isGroupMessage = category == .group
        queue.async {
            var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue,
                                                conversationId: conversationId,
                                                userId: AccountAPI.shared.accountUserId)
            message.mediaStatus = MediaStatus.PENDING.rawValue
            message.mediaUrl = image.fullsizedUrl.absoluteString
            message.mediaWidth = image.size.width
            message.mediaHeight = image.size.height
            if let thumbnail = thumbnail {
                message.thumbImage = thumbnail.base64Thumbnail()
            }
            message.mediaMimeType = "image/gif"
            SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: isGroupMessage)
        }
    }
    
    func send(asset: PHAsset) {
        let conversationId = self.conversationId
        let ownerUser = self.ownerUser
        let isGroupMessage = category == .group
        let options = self.thumbnailRequestOptions
        queue.async {
            assert(asset.mediaType == .image || asset.mediaType == .video)
            let assetMediaTypeIsImage = asset.mediaType == .image
            let category: MessageCategory = assetMediaTypeIsImage ? .SIGNAL_IMAGE : .SIGNAL_VIDEO
            var message = Message.createMessage(category: category.rawValue,
                                                conversationId: conversationId,
                                                userId: AccountAPI.shared.accountUserId)
            message.mediaStatus = MediaStatus.PENDING.rawValue
            message.mediaLocalIdentifier = asset.localIdentifier
            message.mediaWidth = asset.pixelWidth
            message.mediaHeight = asset.pixelHeight
            let thumbnailSize = CGSize(width: 48, height: 48)
            PHImageManager.default().requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFit, options: options) { (image, info) in
                if let image = image {
                    message.thumbImage = image.base64Thumbnail()
                }
            }
            SendMessageService.shared.sendMessage(message: message, ownerUser: ownerUser, isGroupMessage: isGroupMessage)
        }
    }
    
}

// MARK: - Private works
extension ConversationDataSource {
    
    private var canInsertEncryptionHint: Bool {
        if let ownerUser = ownerUser, ownerUser.isBot {
            return false
        } else {
            return true
        }
    }
    
    private func reload(initialMessageId: String? = nil, prepareBeforeReload: (() -> Void)? = nil, completion: (() -> Void)? = nil, animatedReloading: Bool = false) {
        canInsertUnreadHint = true
        var didLoadEarliestMessage = false
        var didLoadLatestMessage = false
        var messages: [MessageItem]
        if initialMessageId != nil {
            ConversationViewController.positions[conversationId] = nil
        }
        var initialMessageId = initialMessageId ?? highlight?.messageId
        if let initialMessageId = initialMessageId, let result = MessageDAO.shared.getMessages(conversationId: conversationId, aroundMessageId: initialMessageId, count: numberOfMessagesOnReloading) {
            (messages, didLoadEarliestMessage, didLoadLatestMessage) = result
            if highlight == nil, initialMessageId != firstUnreadMessageId {
                firstUnreadMessageId = MessageDAO.shared.firstUnreadMessage(conversationId: conversationId)?.messageId
            }
        } else if let firstUnreadMessageId = MessageDAO.shared.firstUnreadMessage(conversationId: conversationId)?.messageId, let result = MessageDAO.shared.getMessages(conversationId: conversationId, aroundMessageId: firstUnreadMessageId, count: numberOfMessagesOnReloading) {
            (messages, didLoadEarliestMessage, didLoadLatestMessage) = result
            self.firstUnreadMessageId = firstUnreadMessageId
        } else if let id = ConversationViewController.positions[conversationId]?.messageId, id == MessageItem.encryptionHintMessageId {
            messages = MessageDAO.shared.getFirstNMessages(conversationId: conversationId, count: numberOfMessagesOnReloading)
            didLoadEarliestMessage = true
            didLoadLatestMessage = messages.count < numberOfMessagesOnReloading
            initialMessageId = id
        } else if let id = ConversationViewController.positions[conversationId]?.messageId, let result = MessageDAO.shared.getMessages(conversationId: conversationId, aroundMessageId: id, count: numberOfMessagesOnReloading) {
            (messages, didLoadEarliestMessage, didLoadLatestMessage) = result
            initialMessageId = id
        } else {
            messages = MessageDAO.shared.getLastNMessages(conversationId: conversationId, count: numberOfMessagesOnReloading)
            didLoadLatestMessage = true
            didLoadEarliestMessage = messages.count < numberOfMessagesOnReloading
            firstUnreadMessageId = nil
        }
        loadedMessageIds = Set(messages.map({ $0.messageId }))
        if messages.count > 0, highlight == nil, let firstUnreadMessageId = self.firstUnreadMessageId, let firstUnreadIndex = messages.firstIndex(where: { $0.messageId == firstUnreadMessageId }) {
            let firstUnreadMessge = messages[firstUnreadIndex]
            let hint = MessageItem.createMessage(category: MessageCategory.EXT_UNREAD.rawValue, conversationId: conversationId, createdAt: firstUnreadMessge.createdAt)
            messages.insert(hint, at: firstUnreadIndex)
            self.firstUnreadMessageId = nil
            canInsertUnreadHint = false
        }
        var (dates, viewModels) = self.viewModels(with: messages, fits: layoutSize.width)
        if canInsertEncryptionHint && didLoadEarliestMessage {
            let date: String
            if let firstDate = dates.first {
                date = firstDate
            } else {
                date = DateFormatter.yyyymmdd.string(from: Date())
                dates.append(date)
            }
            let hint = MessageItem.encryptionHintMessage(conversationId: self.conversationId)
            let viewModel = self.viewModel(withMessage: hint, style: .bottomSeparator, fits: layoutSize.width)
            if viewModels[date] != nil {
                viewModels[date]?.insert(viewModel, at: 0)
            } else {
                viewModels[date] = [viewModel]
            }
        }
        var initialIndexPath: IndexPath?
        var offset: CGFloat = 0
        let unreadMessagesCount = MessageDAO.shared.getUnreadMessagesCount(conversationId: conversationId)
        
        if let initialMessageId = initialMessageId {
            initialIndexPath = indexPath(ofDates: dates, viewModels: viewModels, where: { $0.messageId == initialMessageId })
            if let position = ConversationViewController.positions[conversationId], initialMessageId == position.messageId, highlight == nil {
                offset = position.offset
            } else {
                offset -= ConversationDateHeaderView.height
            }
        } else if let unreadHintIndexPath = indexPath(ofDates: dates, viewModels: viewModels, where: { $0.category == MessageCategory.EXT_UNREAD.rawValue }) {
            if unreadHintIndexPath == IndexPath(row: 1, section: 0), viewModels[dates[0]]?.first?.message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
                initialIndexPath = IndexPath(row: 0, section: 0)
            } else {
                initialIndexPath = unreadHintIndexPath
            }
            offset -= ConversationDateHeaderView.height
        }
        performSynchronouslyOnMainThread {
            guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                return
            }
            prepareBeforeReload?()
            self.dates = dates
            self.viewModels = viewModels
            tableView.reloadData()
            self.didLoadEarliestMessage = didLoadEarliestMessage
            self.didLoadLatestMessage = didLoadLatestMessage
            let scrolling: () -> Void = {
                if let initialIndexPath = initialIndexPath {
                    if tableView.contentSize.height > self.layoutSize.height {
                        let rect = tableView.rectForRow(at: initialIndexPath)
                        let y = rect.origin.y + offset - tableView.contentInset.top
                        tableView.setContentOffsetYSafely(y)
                    }
                } else {
                    tableView.scrollToBottom(animated: false)
                }
            }
            if animatedReloading {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: scrolling, completion: nil)
            } else {
                scrolling()
            }
            if ConversationViewController.positions[self.conversationId] != nil && !tableView.visibleCells.contains(where: { $0 is UnreadHintMessageCell }) {
                NotificationCenter.default.post(name: ConversationDataSource.didAddMessageOutOfBoundsNotification, object: unreadMessagesCount)
            }
            ConversationViewController.positions[self.conversationId] = nil
            SendMessageService.shared.sendReadMessages(conversationId: self.conversationId)
            self.didInitializedData = true
            completion?()
        }
    }
    
    private func indexPath(ofDates dates: [String], viewModels: [String: [MessageViewModel]], where predicate: (MessageItem) -> Bool) -> IndexPath? {
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
    
    typealias CategorizedViewModels = (dates: [String], viewModels: [String: [MessageViewModel]])
    private func viewModels(with messages: [MessageItem], fits layoutWidth: CGFloat) -> CategorizedViewModels {
        var dates = [String]()
        var cataloguedMessages = [String: [MessageItem]]()
        for i in 0..<messages.count {
            let message = messages[i]
            let date = DateFormatter.yyyymmdd.string(from: message.createdAt.toUTCDate())
            if cataloguedMessages[date] != nil {
                cataloguedMessages[date]!.append(message)
            } else {
                cataloguedMessages[date] = [message]
            }
        }
        dates = cataloguedMessages.keys.sorted(by: <)
        
        var viewModels = [String: [MessageViewModel]]()
        for date in dates {
            let messages = cataloguedMessages[date] ?? []
            for (row, message) in messages.enumerated() {
                let style = self.style(forIndex: row, messages: messages)
                let viewModel = self.viewModel(withMessage: message, style: style, fits: layoutWidth)
                if viewModels[date] != nil {
                    viewModels[date]!.append(viewModel)
                } else {
                    viewModels[date] = [viewModel]
                }
            }
        }
        return (dates: dates, viewModels: viewModels)
    }
    
    private func viewModel(withMessage message: MessageItem, style: MessageViewModel.Style, fits layoutWidth: CGFloat) -> MessageViewModel {
        let viewModel: MessageViewModel
        if message.status == MessageStatus.FAILED.rawValue {
            viewModel = DecryptionFailedMessageViewModel(message: message, style: style, fits: layoutWidth)
        } else {
            if message.quoteMessageId != nil && message.quoteContent != nil {
                viewModel = QuoteTextMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_TEXT") {
                viewModel = TextMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_IMAGE") {
                viewModel = PhotoMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_STICKER") {
                viewModel = StickerMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_DATA") {
                viewModel = DataMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_VIDEO") {
                viewModel = VideoMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_AUDIO") {
                viewModel = AudioMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_CONTACT") {
                viewModel = ContactMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasSuffix("_LIVE") {
                viewModel = LiveMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category.hasPrefix("WEBRTC_") {
                viewModel = CallMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                viewModel = TransferMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category == MessageCategory.SYSTEM_CONVERSATION.rawValue {
                viewModel = SystemMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category == MessageCategory.APP_BUTTON_GROUP.rawValue {
                viewModel = AppButtonGroupViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category == MessageCategory.APP_CARD.rawValue {
                viewModel = AppCardMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category == MessageCategory.MESSAGE_RECALL.rawValue {
                viewModel = RecalledMessageViewModel(message: message, style: style, fits: layoutWidth)
            } else if message.category == MessageCategory.EXT_UNREAD.rawValue {
                viewModel = MessageViewModel(message: message, style: style, fits: layoutWidth)
                viewModel.cellHeight = 38
            } else if message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
                viewModel = EncryptionHintViewModel(message: message, style: style, fits: layoutWidth)
            } else {
                viewModel = UnknownMessageViewModel(message: message, style: style, fits: layoutWidth)
            }
            if let viewModel = viewModel as? TextMessageViewModel, let keyword = highlight?.keyword {
                viewModel.highlight(keyword: keyword)
            }
        }
        return viewModel
    }
    
    private func style(forIndex index: Int, isFirstMessage: Bool, isLastMessage: Bool, messageAtIndex: (Int) -> MessageItem) -> MessageViewModel.Style {
        let message = messageAtIndex(index)
        var style: MessageViewModel.Style = []
        if message.userId != me.user_id {
            style = .received
        }
        if isLastMessage
            || messageAtIndex(index + 1).userId != message.userId
            || messageAtIndex(index + 1).isExtensionMessage
            || messageAtIndex(index + 1).isSystemMessage {
            style.insert(.tail)
        }
        if message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
            style.insert(.bottomSeparator)
        } else if !isLastMessage && (message.isSystemMessage
            || messageAtIndex(index + 1).userId != message.userId
            || messageAtIndex(index + 1).isSystemMessage
            || messageAtIndex(index + 1).isExtensionMessage) {
            style.insert(.bottomSeparator)
        }
        if message.isRepresentativeMessage(conversation: conversation) {
            if (isFirstMessage && !message.isExtensionMessage && !message.isSystemMessage)
                || (!isFirstMessage && (messageAtIndex(index - 1).userId != message.userId || messageAtIndex(index - 1).isExtensionMessage || messageAtIndex(index - 1).isSystemMessage)) {
                style.insert(.fullname)
            }
        }
        return style
    }
    
    private func style(forIndex index: Int, messages: [MessageItem]) -> MessageViewModel.Style {
        return style(forIndex: index,
                     isFirstMessage: index == 0,
                     isLastMessage: index == messages.count - 1,
                     messageAtIndex: { messages[$0] })
    }
    
    private func style(forIndex index: Int, viewModels: [MessageViewModel]) -> MessageViewModel.Style {
        return style(forIndex: index,
                     isFirstMessage: index == 0,
                     isLastMessage: index == viewModels.count - 1,
                     messageAtIndex: { viewModels[$0].message })
    }
    
    private func addMessageAndDisplay(message: MessageItem) {
        let messageIsSentByMe = message.userId == me.user_id
        let date = DateFormatter.yyyymmdd.string(from: message.createdAt.toUTCDate())
        let lastIndexPathBeforeInsertion = lastIndexPath
        var style: MessageViewModel.Style = []
        if !messageIsSentByMe {
            style.insert(.received)
        }
        let needsInsertNewSection: Bool
        let section: Int
        let row: Int
        let isLastCell: Bool
        let viewModel: MessageViewModel
        let shouldRemoveAllHighlights = messageIsSentByMe && highlight != nil
        if shouldRemoveAllHighlights {
            highlight = nil
        }
        if let viewModels = viewModels[date] {
            needsInsertNewSection = false
            section = dates.firstIndex(of: date)!
            if let index = viewModels.firstIndex(where: { $0.message.createdAt > message.createdAt }) {
                isLastCell = false
                row = index
            } else {
                isLastCell = true
                row = viewModels.count
                style.insert(.tail)
            }
            if row - 1 >= 0 {
                let previousViewModel = viewModels[row - 1]
                let previousViewModelIsFromDifferentUser = previousViewModel.message.userId != message.userId
                if previousViewModel.message.isSystemMessage || message.isSystemMessage || message.isExtensionMessage {
                    if !messageIsSentByMe {
                        style.insert(.fullname)
                    }
                    previousViewModel.style.insert(.bottomSeparator)
                } else if previousViewModelIsFromDifferentUser {
                    previousViewModel.style.insert(.bottomSeparator)
                    previousViewModel.style.insert(.tail)
                } else {
                    previousViewModel.style.remove(.bottomSeparator)
                    previousViewModel.style.remove(.tail)
                }
                if message.isRepresentativeMessage(conversation: conversation) && style.contains(.received) && previousViewModelIsFromDifferentUser {
                    style.insert(.fullname)
                }
                DispatchQueue.main.sync {
                    guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                        return
                    }
                    if let previousIndexPath = self.lastIndexPath, let previousCell = tableView.cellForRow(at: previousIndexPath) as? MessageCell {
                        previousCell.render(viewModel: previousViewModel)
                    }
                }
            }
            viewModel = self.viewModel(withMessage: message, style: style, fits: layoutSize.width)
            if !isLastCell {
                let nextViewModel = viewModels[row]
                if viewModel.message.userId != nextViewModel.message.userId {
                    viewModel.style.insert(.tail)
                    viewModel.style.insert(.bottomSeparator)
                    if nextViewModel.message.isRepresentativeMessage(conversation: conversation) && nextViewModel.style.contains(.received) {
                        nextViewModel.style.insert(.fullname)
                    }
                } else {
                    viewModel.style.remove(.tail)
                    viewModel.style.remove(.bottomSeparator)
                    nextViewModel.style.remove(.fullname)
                }
                DispatchQueue.main.sync {
                    guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                        return
                    }
                    let nextIndexPath = IndexPath(row: row, section: self.dates.firstIndex(of: date)!)
                    if let nextCell = tableView.cellForRow(at: nextIndexPath) as? MessageCell {
                        nextCell.render(viewModel: nextViewModel)
                    }
                }
            }
        } else {
            needsInsertNewSection = true
            section = dates.firstIndex(where: { $0 > date }) ?? dates.count
            row = 0
            isLastCell = section == dates.count
            if style.contains(.received) && message.isRepresentativeMessage(conversation: conversation) {
                style.insert(.fullname)
            }
            viewModel = self.viewModel(withMessage: message, style: style, fits: layoutSize.width)
        }
        DispatchQueue.main.sync {
            guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                return
            }
            if shouldRemoveAllHighlights {
                self.viewModels.values.flatMap({ $0 }).forEach {
                    ($0 as? TextMessageViewModel)?.removeHighlights()
                }
                if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
                    tableView.reloadRows(at: visibleIndexPaths, with: .none)
                }
            }
            let lastMessageIsVisibleBeforeInsertion: Bool
            if let lastIndexPathBeforeInsertion = lastIndexPathBeforeInsertion, let visibleIndexPaths = tableView.indexPathsForVisibleRows, visibleIndexPaths.contains(lastIndexPathBeforeInsertion) {
                lastMessageIsVisibleBeforeInsertion = true
            } else {
                lastMessageIsVisibleBeforeInsertion = false
            }
            UIView.setAnimationsEnabled(false)
            tableView.beginUpdates()
            let indexPath = IndexPath(row: row, section: section)
            if needsInsertNewSection {
                self.dates.insert(date, at: section)
                self.viewModels[date] = [viewModel]
                tableView.insertSections(IndexSet(integer: indexPath.section), with: .none)
            } else {
                self.viewModels[date]!.insert(viewModel, at: row)
                tableView.insertRows(at: [indexPath], with: .none)
            }
            if tableView.tableFooterView != nil && messageIsSentByMe {
                tableView.tableFooterView = nil
            }
            tableView.endUpdates()
            UIView.setAnimationsEnabled(true)
            let shouldScrollToNewMessage = !tableView.isTracking
                && !tableView.isDecelerating
                && isLastCell
                && (lastMessageIsVisibleBeforeInsertion || messageIsSentByMe)
            if shouldScrollToNewMessage {
                tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            } else {
                NotificationCenter.default.postOnMain(name: ConversationDataSource.didAddMessageOutOfBoundsNotification, object: 1)
            }
        }
    }
    
}

// MARK: - Embedded class
extension ConversationDataSource {
    
    enum Category {
        case group
        case contact
    }
    
    struct Highlight {
        let keyword: String
        let messageId: String
    }
    
}

extension MessageItem {
    
    static let encryptionHintMessageId = "encryption_hint"
    
    static func encryptionHintMessage(conversationId: String) -> MessageItem {
        let message = MessageItem()
        message.messageId = encryptionHintMessageId
        message.status = MessageStatus.READ.rawValue
        message.category = MessageCategory.EXT_ENCRYPTION.rawValue
        message.conversationId = conversationId
        message.createdAt = ""
        message.content = Localized.CHAT_CELL_TITLE_ENCRYPTION
        return message
    }
    
}
