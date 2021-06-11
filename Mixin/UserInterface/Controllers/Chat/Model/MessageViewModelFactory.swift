import Foundation
import MixinServices

protocol MessageViewModelFactoryDelegate: AnyObject {
    func messageViewModelFactory(_ factory: MessageViewModelFactory, showUsernameForMessageIfNeeded message: MessageItem) -> Bool
    func messageViewModelFactory(_ factory: MessageViewModelFactory, isMessageForwardedByBot message: MessageItem) -> Bool
    func messageViewModelFactory(_ factory: MessageViewModelFactory, updateViewModelForPresentation viewModel: MessageViewModel)
}

class MessageViewModelFactory {
    
    typealias CategorizedViewModels = (dates: [String], viewModels: [String: [MessageViewModel]])
    
    weak var delegate: MessageViewModelFactoryDelegate?
    
    func viewModels(with messages: [MessageItem], fits layoutWidth: CGFloat) -> CategorizedViewModels {
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
    
    func style(forIndex index: Int, messages: [MessageItem]) -> MessageViewModel.Style {
        style(forIndex: index,
              isFirstMessage: index == 0,
              isLastMessage: index == messages.count - 1,
              messageAtIndex: { messages[$0] })
    }
    
    func style(forIndex index: Int, viewModels: [MessageViewModel]) -> MessageViewModel.Style {
        style(forIndex: index,
              isFirstMessage: index == 0,
              isLastMessage: index == viewModels.count - 1,
              messageAtIndex: { viewModels[$0].message })
    }
    
    func style(
        forIndex index: Int,
        isFirstMessage: Bool,
        isLastMessage: Bool,
        messageAtIndex: (Int) -> MessageItem
    ) -> MessageViewModel.Style {
        let message = messageAtIndex(index)
        var style: MessageViewModel.Style = []
        if message.userId != myUserId {
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
        if delegate?.messageViewModelFactory(self, showUsernameForMessageIfNeeded: message) ?? false {
            if isFirstMessage {
                if !message.isExtensionMessage && !message.isSystemMessage {
                    style.insert(.fullname)
                }
            } else {
                let previousMessageFromDifferentUser = messageAtIndex(index - 1).userId != message.userId
                    || messageAtIndex(index - 1).isExtensionMessage
                    || messageAtIndex(index - 1).isSystemMessage
                if previousMessageFromDifferentUser {
                    style.insert(.fullname)
                }
            }
        }
        if delegate?.messageViewModelFactory(self, isMessageForwardedByBot: message) ?? false {
            style.insert(.forwardedByBot)
        }
        return style
    }
    
    func viewModel(
        withMessage message: MessageItem,
        style: MessageViewModel.Style,
        fits layoutWidth: CGFloat
    ) -> MessageViewModel {
        let viewModel: MessageViewModel
        if message.status == MessageStatus.FAILED.rawValue {
            viewModel = DecryptionFailedMessageViewModel(message: message)
        } else if message.status == MessageStatus.UNKNOWN.rawValue {
            viewModel = UnknownMessageViewModel(message: message)
        } else {
            if message.category.hasSuffix("_TEXT") {
                viewModel = TextMessageViewModel(message: message)
            } else if message.category.hasSuffix("_IMAGE") {
                viewModel = PhotoMessageViewModel(message: message)
            } else if message.category.hasSuffix("_STICKER") {
                viewModel = StickerMessageViewModel(message: message)
            } else if message.category.hasSuffix("_DATA") {
                viewModel = DataMessageViewModel(message: message)
            } else if message.category.hasSuffix("_VIDEO") {
                viewModel = VideoMessageViewModel(message: message)
            } else if message.category.hasSuffix("_AUDIO") {
                viewModel = AudioMessageViewModel(message: message)
            } else if message.category.hasSuffix("_CONTACT") {
                viewModel = ContactMessageViewModel(message: message)
            } else if message.category.hasSuffix("_LIVE") {
                viewModel = LiveMessageViewModel(message: message)
            } else if message.category.hasSuffix("_POST") {
                viewModel = PostMessageViewModel(message: message)
            } else if message.category.hasSuffix("_LOCATION") {
                viewModel = LocationMessageViewModel(message: message)
            } else if message.category.hasPrefix("WEBRTC_") {
                viewModel = CallMessageViewModel(message: message)
            } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                viewModel = TransferMessageViewModel(message: message)
            } else if message.category == MessageCategory.SYSTEM_CONVERSATION.rawValue {
                viewModel = SystemMessageViewModel(message: message)
            } else if message.category == MessageCategory.APP_BUTTON_GROUP.rawValue {
                viewModel = AppButtonGroupViewModel(message: message)
            } else if message.category == MessageCategory.APP_CARD.rawValue {
                viewModel = AppCardMessageViewModel(message: message)
            } else if message.category == MessageCategory.MESSAGE_RECALL.rawValue {
                viewModel = RecalledMessageViewModel(message: message)
            } else if message.category == MessageCategory.EXT_UNREAD.rawValue {
                viewModel = MessageViewModel(message: message)
                viewModel.cellHeight = 38
            } else if message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
                viewModel = EncryptionHintViewModel(message: message)
            } else if MessageCategory.krakenCategories.contains(message.category) {
                viewModel = SystemMessageViewModel(message: message)
            } else if message.category == MessageCategory.SIGNAL_TRANSCRIPT.rawValue {
                viewModel = TranscriptMessageViewModel(message: message)
            } else {
                viewModel = UnknownMessageViewModel(message: message)
            }
        }
        viewModel.layout(width: layoutWidth, style: style)
        delegate?.messageViewModelFactory(self, updateViewModelForPresentation: viewModel)
        return viewModel
    }
    
}
