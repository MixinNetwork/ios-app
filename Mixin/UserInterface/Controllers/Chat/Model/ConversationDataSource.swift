import UIKit
import AVKit
import Photos
import SDWebImage
import CoreServices
import MixinServices

class ConversationDataSource {
    
    enum UserInfoKey {
        static let unreadMessageCount = "unread_count"
        static let mentionedMessageIds = "mention_ids"
    }
    
    static let newMessageOutOfVisibleBoundsNotification = Notification.Name("one.mixin.messenger.ConversationDataSource.MessageOutOfBounds")
    
    let queue = DispatchQueue(label: "one.mixin.ios.conversation.datasource")
    
    var ownerUser: UserItem?
    var firstUnreadMessageId: String?
    var focusIndexPath: IndexPath?
    var selectedViewModels = [String: MessageViewModel]() // Key is message id
    var selectedMessageViewModels: [MessageViewModel] {
        selectedViewModels.values.reduce(into: []) { result, viewModel in
            if viewModel.message.category == MessageCategory.STACKED_PHOTO.rawValue {
                if let messages = viewModel.message.stackedMessageItems, !messages.isEmpty {
                    let models: [MessageViewModel] = factory
                        .viewModels(with: messages, fits: layoutSize.width)
                        .viewModels
                        .reduce([]) { $1.value }
                    result.append(contentsOf: models)
                }
            } else {
                result.append(viewModel)
            }
        }
    }
    
    weak var tableView: ConversationTableView?
    
    private let numberOfConsecutiveImagesToStack = 4
    private let numberOfMessagesOnPaging = 100
    private let numberOfMessagesOnReloading = 35
    private let me = LoginManager.shared.account!
    private let factory = MessageViewModelFactory()
    
    private(set) var conversation: ConversationItem {
        didSet {
            category = conversation.category == ConversationCategory.CONTACT.rawValue ? .contact : .group
        }
    }
    private(set) var dates = [String]()
    private(set) var loadedMessageIds = SafeSet<String>()
    private(set) var didLoadLatestMessage = false
    private(set) var category: Category
    private(set) var stackedPhotoMessages = [MessageItem]()

    private var highlight: Highlight?
    private var viewModels = [String: [MessageViewModel]]()
    private var didLoadEarliestMessage = false
    private var isLoadingAbove = false
    private var isLoadingBelow = false
    private var canInsertUnreadHint = true
    private var messageProcessingIsCancelled = false
    private var didInitializedData = false
    private var pendingPinningUpdateMessageId: String?
    
    var layoutSize: CGSize {
        Queue.main.autoSync {
            var size = AppDelegate.current.mainWindow.bounds.size
            if UIApplication.shared.isLandscape {
                swap(&size.width, &size.height)
            }
            return size
        }
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
    
    var visibleMessageIds: [String] {
        let ids = tableView?.indexPathsForVisibleRows?
            .compactMap(viewModel(for:))
            .map({ $0.message.messageId })
        return ids ?? []
    }
    
    // MARK: - Interface
    init(conversation: ConversationItem, highlight: Highlight? = nil, ownerUser: UserItem? = nil) {
        self.conversation = conversation
        self.highlight = highlight
        self.ownerUser = ownerUser
        self.category = conversation.category == ConversationCategory.CONTACT.rawValue ? .contact : .group
        factory.delegate = self
    }
    
    func initData(completion: @escaping () -> Void) {
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: MixinServices.conversationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(messageDaoDidInsertMessage(_:)), name: MessageDAO.didInsertMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(messageDaoDidRedecryptMessage(_:)), name: MessageDAO.didRedecryptMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMediaProgress(_:)), name: AttachmentLoadingJob.progressNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMessageMediaStatus(_:)), name: MessageDAO.messageMediaStatusDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMessagePinning(_:)), name: PinMessageDAO.didSaveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMessagePinning(_:)), name: PinMessageDAO.didDeleteNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(messageDidDelete(_:)), name: MessageDAO.didDeleteMessageNotification, object: nil)
        reload(completion: completion)
    }
    
    func cancelMessageProcessing() {
        messageProcessingIsCancelled = true
        NotificationCenter.default.removeObserver(self)
    }
    
    func reload(initialMessageId: String? = nil, prepareBeforeReload: (() -> Void)? = nil, completion: (() -> Void)? = nil, animatedReloading: Bool = false) {
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
        loadedMessageIds = SafeSet<String>(messages.map({ $0.messageId }))
        if messages.count > 0, highlight == nil, let firstUnreadMessageId = self.firstUnreadMessageId, let firstUnreadIndex = messages.firstIndex(where: { $0.messageId == firstUnreadMessageId }) {
            let firstUnreadMessge = messages[firstUnreadIndex]
            let hint = MessageItem(category: MessageCategory.EXT_UNREAD.rawValue, conversationId: conversationId, createdAt: firstUnreadMessge.createdAt)
            messages.insert(hint, at: firstUnreadIndex)
            self.firstUnreadMessageId = nil
            canInsertUnreadHint = false
        }
        messages = stackConsecutiveImageMessagesIfneeded(messages)
        var (dates, viewModels) = factory.viewModels(with: messages, fits: layoutSize.width)
        if canInsertEncryptionHint && didLoadEarliestMessage {
            let date: String
            if let firstDate = dates.first {
                date = firstDate
            } else {
                date = DateFormatter.yyyymmdd.string(from: Date())
                dates.append(date)
            }
            let hint = MessageItem.encryptionHintMessage(conversationId: self.conversationId)
            let viewModel = factory.viewModel(withMessage: hint, style: .bottomSeparator, fits: layoutSize.width)
            if viewModels[date] != nil {
                viewModels[date]?.insert(viewModel, at: 0)
            } else {
                viewModels[date] = [viewModel]
            }
        }
        var initialIndexPath: IndexPath?
        var offset: CGFloat = 0
        let unreadMessagesCount = MessageDAO.shared.getUnreadMessagesCount(conversationId: conversationId)
        var unreadMentionMessageIds = MessageMentionDAO.shared.unreadMessageIds(conversationId: conversationId)
        
        if let initialMessageId = initialMessageId {
            initialIndexPath = firstIndexPath(ofDates: dates, viewModels: viewModels, where: { $0.messageId == initialMessageId })
            if let position = ConversationViewController.positions[conversationId], initialMessageId == position.messageId, highlight == nil {
                offset = position.offset
            } else {
                offset -= ConversationDateHeaderView.height
            }
        } else if let unreadHintIndexPath = firstIndexPath(ofDates: dates, viewModels: viewModels, where: { $0.category == MessageCategory.EXT_UNREAD.rawValue }) {
            if unreadHintIndexPath == IndexPath(row: 1, section: 0), viewModels[dates[0]]?.first?.message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
                initialIndexPath = IndexPath(row: 0, section: 0)
            } else {
                initialIndexPath = unreadHintIndexPath
            }
            offset -= ConversationDateHeaderView.height
        }
        Queue.main.autoSync {
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
                    self.focusIndexPath = initialIndexPath
                    if tableView.contentSize.height > self.layoutSize.height {
                        let rect = tableView.rectForRow(at: initialIndexPath)
                        let y = rect.origin.y + offset - tableView.contentInset.top
                        tableView.setContentOffsetYSafely(y)
                    }
                } else {
                    self.focusIndexPath = self.lastIndexPath
                    tableView.scrollToBottom(animated: false)
                }
            }
            if animatedReloading {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: scrolling, completion: nil)
            } else {
                scrolling()
            }
            if ConversationViewController.positions[self.conversationId] != nil {
                var userInfo = [String: Any]()
                if !tableView.visibleCells.contains(where: { $0 is UnreadHintMessageCell }) {
                    userInfo[Self.UserInfoKey.unreadMessageCount] = unreadMessagesCount
                }
                unreadMentionMessageIds.removeAll(where: self.visibleMessageIds.contains)
                if !unreadMentionMessageIds.isEmpty {
                    userInfo[Self.UserInfoKey.mentionedMessageIds] = unreadMentionMessageIds
                }
                NotificationCenter.default.post(name: Self.newMessageOutOfVisibleBoundsNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
            ConversationViewController.positions[self.conversationId] = nil
            if UIApplication.shared.applicationState == .active {
                SendMessageService.shared.sendReadMessages(conversationId: self.conversationId)
            }
            self.didInitializedData = true
            selectTableViewRowsWithPreviousSelection()
            completion?()
        }
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
            messages = self.stackConsecutiveImageMessagesIfneeded(messages)
            var (dates, viewModels) = self.factory.viewModels(with: messages, fits: layoutWidth)
            if shouldInsertEncryptionHint {
                let hint = MessageItem.encryptionHintMessage(conversationId: conversationId)
                messages.insert(hint, at: 0)
                let encryptionHintViewModel = self.factory.viewModel(withMessage: hint, style: .bottomSeparator, fits: layoutWidth)
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
                let styles = Array(0..<messagesForTheDate.count).map{
                    self.factory.style(forIndex: $0, messages: messagesForTheDate)
                }
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
                self.selectTableViewRowsWithPreviousSelection()
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
                let hint = MessageItem(category: MessageCategory.EXT_UNREAD.rawValue, conversationId: conversationId, createdAt: firstUnreadMessage.createdAt)
                messages.insert(hint, at: index)
                self.canInsertUnreadHint = false
            }
            messages = self.stackConsecutiveImageMessagesIfneeded(messages)
            let (dates, viewModels) = self.factory.viewModels(with: messages, fits: layoutWidth)
            if let firstDate = dates.first, let messagesBeforeAppend = self.viewModels[firstDate]?.suffix(2).map({ $0.message }) {
                let messagesForTheDate = messagesBeforeAppend + messages.prefix(2)
                let styles = Array(0..<messagesForTheDate.count).map {
                    self.factory.style(forIndex: $0, messages: messagesForTheDate)
                }
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
                self.selectTableViewRowsWithPreviousSelection()
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
                let style = factory.style(forIndex: indexBeforeDeletedMessage, viewModels: viewModels)
                self.viewModels[date]?[indexBeforeDeletedMessage].style = style
            }
            if indexAfterDeletedMessage < viewModels.count {
                let style = factory.style(forIndex: indexAfterDeletedMessage, viewModels: viewModels)
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
        return firstIndexPath(ofDates: dates, viewModels: viewModels, where: predicate)
    }
    
    func postponeMessagePinningUpdate(with messageId: String) {
        pendingPinningUpdateMessageId = messageId
    }
    
    func performPendingMessagePinningUpdate() {
        guard let id = pendingPinningUpdateMessageId else {
            return
        }
        updateMessage(messageId: id)
        pendingPinningUpdateMessageId = nil
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
        case .updateConversationStatus(let status):
            self.conversation.status = status.rawValue
        case .updateGroupIcon(let iconUrl):
            conversation.iconUrl = iconUrl
        case .updateMessage(let messageId):
            updateMessage(messageId: messageId)
        case .updateMessageStatus(let messageId, let newStatus):
            updateMessageStatus(messageId: messageId, status: newStatus)
        case .updateMessageMentionStatus(let messageId, let newStatus):
            updateMessageMentionStatus(messageId: messageId, status: newStatus)
        case .updateMediaKey(let messageId, let content, let key, let digest):
            updateMediaKey(messageId: messageId, content: content, key: key, digest: digest)
        case .updateMediaContent(let messageId, let message):
            updateMediaContent(messageId: messageId, message: message)
        case .recallMessage(let messageId):
            recallMessage(messageId: messageId)
        case .updateExpireIn(let expireIn, let messageId):
            conversation.expireIn = expireIn
            if let messageId = messageId {
                updateMessage(messageId: messageId)
            }
        case .updateConversation, .startedUpdateConversation:
            break
        }
    }
    
    @objc func messageDaoDidInsertMessage(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[MessageDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        guard let message = notification.userInfo?[MessageDAO.UserInfoKey.message] as? MessageItem else {
            return
        }
        guard !loadedMessageIds.contains(message.messageId) else {
            return
        }
        let messageIsSentByMe = message.userId == me.userID
        if !messageIsSentByMe && message.status == MessageStatus.DELIVERED.rawValue {
            Queue.main.autoSync {
                guard UIApplication.shared.applicationState == .active else {
                    return
                }
                SendMessageService.shared.sendReadMessages(conversationId: message.conversationId)
            }
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
                postNewMessageOutOfBoundsNotification(message: message)
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
    
    @objc func messageDaoDidRedecryptMessage(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[MessageDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        guard let message = notification.userInfo?[MessageDAO.UserInfoKey.message] as? MessageItem else {
            return
        }
        updateMessage(messageId: message.messageId)
    }
    
    @objc private func updateMediaProgress(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let conversationId = userInfo[AttachmentLoadingJob.UserInfoKey.conversationId] as? String,
            let messageId = userInfo[AttachmentLoadingJob.UserInfoKey.messageId] as? String,
            let progress = userInfo[AttachmentLoadingJob.UserInfoKey.progress] as? Double,
            conversationId == self.conversationId,
            let indexPath = indexPath(where: { $0.messageId == messageId }),
            let viewModel = viewModel(for: indexPath) as? MessageViewModel & AttachmentLoadingViewModel
        else {
            return
        }
        viewModel.progress = progress
        if let cell = tableView?.cellForRow(at: indexPath) as? AttachmentLoadingMessageCell {
            cell.updateProgress()
        }
    }
    
    @objc private func updateMessageMediaStatus(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let messageId = userInfo[MessageDAO.UserInfoKey.messageId] as? String,
            let mediaStatus = userInfo[MessageDAO.UserInfoKey.mediaStatus] as? MediaStatus,
            let indexPath = indexPath(where: { $0.messageId == messageId })
        else {
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
        } else {
            viewModel?.message.mediaStatus = mediaStatus.rawValue
        }
        if let cell = cell as? AudioMessageCell {
            cell.updateUnreadStyle()
        }
    }
    
    @objc private func updateMessagePinning(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[PinMessageDAO.UserInfoKey.conversationId] as? String, conversationId == self.conversationId else {
            return
        }
        if let id = notification.userInfo?[PinMessageDAO.UserInfoKey.referencedMessageId] as? String {
            if id == pendingPinningUpdateMessageId {
                // This id is request to be updated later, do nothing here and wait for the func of performPendingMessagePinningUpdate
            } else {
                updateMessage(messageId: id)
            }
        } else if let ids = notification.userInfo?[PinMessageDAO.UserInfoKey.referencedMessageIds] as? [String] {
            ids.forEach(updateMessage(messageId:))
        }
    }
    
    @objc private func messageDidDelete(_ notification: Notification) {
        guard let messageId = notification.userInfo?[MessageDAO.UserInfoKey.messageId] as? String else {
            return
        }
        queue.async {
            var deletePhotoMessage = false
            for (index, message) in self.stackedPhotoMessages.enumerated() {
                guard
                    var imageMessages = message.stackedMessageItems,
                    let deletedMessageIndex = imageMessages.firstIndex(where: { $0.messageId == messageId }),
                    let viewModelIndexPath = self.indexPath(where: { $0.messageId == message.messageId })
                else {
                    continue
                }
                imageMessages.remove(at: deletedMessageIndex)
                message.stackedMessageItems = imageMessages
                if deletedMessageIndex == 0 {
                    message.messageId = imageMessages[0].messageId
                }
                if imageMessages.count < self.numberOfConsecutiveImagesToStack {
                    DispatchQueue.main.sync {
                        guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                            return
                        }
                        _ = self.removeViewModel(at: viewModelIndexPath)
                        self.stackedPhotoMessages.remove(at: index)
                        tableView.reloadData()
                    }
                    imageMessages.forEach(self.addMessageAndDisplay(message:))
                } else {
                    DispatchQueue.main.sync {
                        guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                            return
                        }
                        let date = DateFormatter.yyyymmdd.string(from: message.createdAt.toUTCDate())
                        if let style = self.viewModels[date]?[viewModelIndexPath.row].style {
                            let viewModel = self.factory.viewModel(withMessage: message, style: style, fits: self.layoutSize.width)
                            self.viewModels[date]?[viewModelIndexPath.row] = viewModel
                            tableView.reloadData()
                        }
                    }
                }
                deletePhotoMessage = true
                break
            }
            if !deletePhotoMessage {
                guard let indexPath = self.indexPath(where: { $0.messageId == messageId }) else {
                    return
                }
                DispatchQueue.main.sync {
                    guard let tableView = self.tableView else {
                        return
                    }
                    _ = self.removeViewModel(at: indexPath)
                    tableView.reloadData()
                }
            }
        }
    }
    
    private func recallMessage(messageId: String) {
        queue.async {
            guard !self.messageProcessingIsCancelled else {
                return
            }
            var recallStackedPhotoMessage = false
            for (index, message) in self.stackedPhotoMessages.enumerated() {
                guard
                    var imageMessages = message.stackedMessageItems,
                    let recallMessageIndex = imageMessages.firstIndex(where: { $0.messageId == messageId }),
                    let viewModelIndexPath = self.indexPath(where: { $0.messageId == message.messageId }),
                    let recalledMessage = MessageDAO.shared.getFullMessage(messageId: messageId)
                else {
                    continue
                }
                imageMessages[recallMessageIndex] = recalledMessage
                DispatchQueue.main.sync {
                    guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                        return
                    }
                    _ = self.removeViewModel(at: viewModelIndexPath)
                    self.stackedPhotoMessages.remove(at: index)
                    tableView.reloadData()
                }
                imageMessages.forEach(self.addMessageAndDisplay(message:))
                recallStackedPhotoMessage = true
                break
            }
            if !recallStackedPhotoMessage {
                self.updateMessage(messageId: messageId)
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
    
    private func updateMessageMentionStatus(messageId: String, status: MessageMentionStatus) {
        guard let indexPath = indexPath(where: { $0.messageId == messageId }) else {
            return
        }
        guard let message = viewModel(for: indexPath)?.message else {
            return
        }
        message.hasMentionRead = status == .MENTION_READ
    }
    
    private func updateMediaKey(messageId: String, content: String, key: Data?, digest: Data?) {
        guard let indexPath = indexPath(where: { $0.messageId == messageId }), let viewModel = viewModel(for: indexPath) else {
            return
        }
        viewModel.updateKey(content: content,
                         key: key,
                         digest: digest)
    }
    
    private func updateMediaContent(messageId: String, message: Message) {
        queue.async {
            // Dispatch view model's processing synchornously inside processing queue
            // to prevent the "missing view model" problem
            DispatchQueue.main.sync {
                guard
                    !self.messageProcessingIsCancelled,
                    let indexPath = self.indexPath(where: { $0.messageId == messageId }),
                    let viewModel = self.viewModel(for: indexPath) as? PhotoRepresentableMessageViewModel
                else {
                    return
                }
                viewModel.update(mediaUrl: message.mediaUrl,
                                 mediaSize: message.mediaSize,
                                 mediaDuration: message.mediaDuration)
                if let cell = self.tableView?.cellForRow(at: indexPath) as? PhotoRepresentableMessageCell {
                    cell.reloadMedia(viewModel: viewModel)
                }
            }
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
            
            if message.status == MessageStatus.DELIVERED.rawValue && message.userId != myUserId {
                Queue.main.autoSync {
                    guard UIApplication.shared.applicationState == .active else {
                        return
                    }
                    SendMessageService.shared.sendReadMessages(conversationId: message.conversationId)
                }
            }
            
            DispatchQueue.main.sync {
                guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                    return
                }
                let date = DateFormatter.yyyymmdd.string(from: message.createdAt.toUTCDate())
                guard
                    let viewModel = self.viewModels[date]?[indexPath.row],
                    viewModel.message.category != MessageCategory.STACKED_PHOTO.rawValue
                else {
                    return
                }
                let model = self.factory.viewModel(withMessage: message, style: viewModel.style, fits: self.layoutSize.width)
                self.viewModels[date]?[indexPath.row] = model
                tableView.reloadData()
                self.selectTableViewRowsWithPreviousSelection()
            }
        }
    }
    
}

// MARK: - MessageViewModelFactoryDelegate
extension ConversationDataSource: MessageViewModelFactoryDelegate {
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, showUsernameForMessageIfNeeded message: MessageItem) -> Bool {
        message.isRepresentativeMessage(conversation: conversation)
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, isMessageForwardedByBot message: MessageItem) -> Bool {
        isMessageForwardedByBot(message)
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, updateViewModelForPresentation viewModel: MessageViewModel) {
        if let viewModel = viewModel as? TextMessageViewModel, let keyword = highlight?.keyword {
            viewModel.highlight(keyword: keyword)
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
    
    private func firstIndexPath(ofDates dates: [String], viewModels: [String: [MessageViewModel]], where predicate: (MessageItem) -> Bool) -> IndexPath? {
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
    
    private func indexPaths(passing test: (MessageItem) -> Bool) -> [IndexPath] {
        var indexPaths = [IndexPath]()
        for (section, date) in dates.enumerated() {
            let viewModels = self.viewModels[date]!
            for (row, viewModel) in viewModels.enumerated() {
                if test(viewModel.message) {
                    let indexPath = IndexPath(row: row, section: section)
                    indexPaths.append(indexPath)
                }
            }
        }
        return indexPaths
    }
    
    private func selectTableViewRowsWithPreviousSelection() {
        guard let tableView = tableView else {
            return
        }
        for indexPath in indexPaths(passing: { selectedViewModels[$0.messageId] != nil }) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
    private func isMessageForwardedByBot(_ message: MessageItem) -> Bool {
        if let ownerUser = ownerUser {
            return ownerUser.isBot
                && message.userId != me.userID
                && message.userId != ownerUser.userId
        } else {
            return false
        }
    }
    
    private func addMessageAndDisplay(message: MessageItem) {
        let messageIsSentByMe = message.userId == me.userID
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
            let previousRow = row - 1
            if previousRow >= 0 {
                let previousViewModel = viewModels[previousRow]
                let previousViewModelIsFromDifferentUser = previousViewModel.message.userId != message.userId
                if previousViewModel.message.isSystemMessage || message.isSystemMessage || message.isExtensionMessage {
                    if !messageIsSentByMe {
                        style.insert(.fullname)
                    }
                    previousViewModel.style.insert(.bottomSeparator)
                } else if previousViewModelIsFromDifferentUser {
                    previousViewModel.style.formUnion([.bottomSeparator, .tail])
                } else {
                    previousViewModel.style.subtract([.bottomSeparator, .tail])
                }
                if message.isRepresentativeMessage(conversation: conversation) && style.contains(.received) && previousViewModelIsFromDifferentUser {
                    style.insert(.fullname)
                }
                if isMessageForwardedByBot(message) {
                    style.insert(.forwardedByBot)
                }
                DispatchQueue.main.sync {
                    guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                        return
                    }
                    let previousIndexPath = IndexPath(row: previousRow, section: section)
                    if let previousCell = tableView.cellForRow(at: previousIndexPath) as? MessageCell {
                        previousCell.render(viewModel: previousViewModel)
                    }
                }
            }
            viewModel = factory.viewModel(withMessage: message, style: style, fits: layoutSize.width)
            if !isLastCell {
                let nextViewModel = viewModels[row]
                if viewModel.message.userId != nextViewModel.message.userId {
                    viewModel.style.formUnion([.bottomSeparator, .tail])
                    if nextViewModel.message.isRepresentativeMessage(conversation: conversation) && nextViewModel.style.contains(.received) {
                        nextViewModel.style.insert(.fullname)
                    }
                } else {
                    viewModel.style.subtract([.bottomSeparator, .tail])
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
            viewModel = factory.viewModel(withMessage: message, style: style, fits: layoutSize.width)
        }
        DispatchQueue.main.sync {
            guard let tableView = self.tableView, !self.messageProcessingIsCancelled else {
                return
            }
            tableView.indexPathsForSelectedRows?.forEach({ (indexPath) in
                tableView.deselectRow(at: indexPath, animated: false)
            })
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
                && !(message.category == MessageCategory.MESSAGE_PIN.rawValue && messageIsSentByMe)
            if shouldScrollToNewMessage {
                if tableView.tableFooterView == nil {
                    tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
                } else {
                    tableView.scrollToBottom(animated: false)
                }
            } else {
                postNewMessageOutOfBoundsNotification(message: message)
            }
            selectTableViewRowsWithPreviousSelection()
        }
    }
    
    func postNewMessageOutOfBoundsNotification(message: MessageItem) {
        var userInfo: [String: Any] = [UserInfoKey.unreadMessageCount: 1]
        if message.category != MessageCategory.MESSAGE_PIN.rawValue, message.mentions?[myIdentityNumber] != nil {
            userInfo[UserInfoKey.mentionedMessageIds] = [message.messageId]
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.newMessageOutOfVisibleBoundsNotification,
                                            object: self,
                                            userInfo: userInfo)
        }
    }
    
    private func stackConsecutiveImageMessagesIfneeded(_ messages: [MessageItem]) -> [MessageItem] {
        guard messages.count >= numberOfConsecutiveImagesToStack else {
            return messages
        }
        func createStackedPhotoMessage(_ messages: [MessageItem]) -> MessageItem {
            let message = messages[0]
            let item = MessageItem(messageId: message.messageId,
                                   conversationId: message.conversationId,
                                   userId: message.userId,
                                   category: MessageCategory.STACKED_PHOTO.rawValue,
                                   thumbImage: message.thumbImage,
                                   status: message.status,
                                   createdAt: message.createdAt,
                                   userFullName: message.userFullName,
                                   userIdentityNumber: message.userIdentityNumber,
                                   userAvatarUrl: message.userAvatarUrl,
                                   messageItems: messages)
            stackedPhotoMessages.append(item)
            return item
        }
        func canStack(_ message: MessageItem) -> Bool {
            message.category.hasSuffix("_IMAGE") && message.quoteMessageId.isNilOrEmpty && message.mediaStatus == MediaStatus.DONE.rawValue
        }
        var result = [MessageItem]()
        var messagesToStack = [MessageItem]()
        var startIndex = 0
        var endIndex = 1
        while endIndex < messages.count {
            let startMessage = messages[startIndex]
            let endMessage = messages[endIndex]
            if canStack(startMessage), canStack(endMessage), startMessage.userId == endMessage.userId {
                if startIndex == 0, messagesToStack.isEmpty {
                    messagesToStack.append(startMessage)
                }
                messagesToStack.append(endMessage)
                endIndex += 1
                if endIndex >= messages.count {
                    if messagesToStack.count < numberOfConsecutiveImagesToStack {
                        result.append(contentsOf: messagesToStack)
                    } else {
                        result.append(createStackedPhotoMessage(messagesToStack))
                    }
                }
            } else {
                if messagesToStack.isEmpty {
                    result.append(contentsOf: messages[startIndex..<endIndex])
                } else if messagesToStack.count < numberOfConsecutiveImagesToStack {
                    result.append(contentsOf: messagesToStack)
                    messagesToStack.removeAll()
                } else {
                    result.append(createStackedPhotoMessage(messagesToStack))
                    messagesToStack.removeAll()
                }
                if canStack(endMessage) {
                    messagesToStack.append(endMessage)
                    startIndex = endIndex
                    endIndex += 1
                    if endIndex >= messages.count {
                        if messagesToStack.count < numberOfConsecutiveImagesToStack {
                            result.append(contentsOf: messagesToStack)
                        } else {
                            result.append(createStackedPhotoMessage(messagesToStack))
                        }
                    }
                } else {
                    result.append(endMessage)
                    startIndex = endIndex + 1
                    endIndex = startIndex + 1
                    if startIndex < messages.count {
                        let message = messages[startIndex]
                        if startIndex == messages.count - 1 {
                            result.append(message)
                        } else if canStack(message) {
                            messagesToStack.append(message)
                        }
                    }
                }
            }
        }
        return result
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
        let message = MessageItem(messageId: encryptionHintMessageId,
                                  conversationId: conversationId,
                                  userId: "",
                                  category: MessageCategory.EXT_ENCRYPTION.rawValue,
                                  content: R.string.localizable.message_e2ee(),
                                  status: MessageStatus.READ.rawValue,
                                  createdAt: "")
        return message
    }
    
}
