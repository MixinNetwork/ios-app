import Foundation
import MixinServices

class CleanUpLargeQuoteContentJob: AsynchronousJob {
    
    private let limit = 100
    private var rowId: Int?
    
    override func getJobId() -> String {
        return "clean-up-large-quote-content"
    }
    
    override func execute() -> Bool {
        while true {
            let messages = MessageDAO.shared.largeQuoteContentMessages(limit: limit, after: rowId)
            if messages.isEmpty {
                AppGroupUserDefaults.User.hasCleanedUpLargeQuoteContent = true
                return true
            }
            for message in messages {
                let quotedMessage: MessageItem
                if let m = MessageDAO.shared.getNonFailedMessage(messageId: message.quoteMessageId) {
                    quotedMessage = m
                } else if let m = try? JSONDecoder.default.decode(MessageItem.self, from: message.quoteContent) {
                    quotedMessage = m
                } else {
                    continue
                }
                if let thumbImage = quotedMessage.thumbImage, thumbImage.utf8.count > maxThumbImageLength {
                    quotedMessage.thumbImage = defaultThumbImage
                }
                quotedMessage.quoteContent = nil
                quotedMessage.quoteMessageId = nil
                if let content = try? JSONEncoder.default.encode(quotedMessage) {
                    MessageDAO.shared.updateQuoteContent(content: content, messageId: message.messageId)
                }
            }
            Logger.general.info(category: "CleanUpLargeQuoteContentJob", message: "Cleaned up \(messages.count)")
            if messages.count < limit {
                AppGroupUserDefaults.User.hasCleanedUpLargeQuoteContent = true
                return true
            }
            rowId = messages.last?.rowId
        }
    }
    
}
