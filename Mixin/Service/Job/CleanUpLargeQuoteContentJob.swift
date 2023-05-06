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
                let content: Data?
                if let quoteMessage = MessageDAO.shared.getNonFailedMessage(messageId: message.quoteMessageId) {
                    if let thumbImage = quoteMessage.thumbImage, thumbImage.utf8.count > maxThumbImageLength {
                        quoteMessage.thumbImage = defaultThumbImage
                    }
                    quoteMessage.quoteContent = nil
                    quoteMessage.quoteMessageId = nil
                    content = try? JSONEncoder.default.encode(quoteMessage)
                } else {
                    content = nil
                }
                MessageDAO.shared.updateQuoteContent(content: content,
                                                     conversationId: message.conversationId,
                                                     messageId: message.quoteMessageId)
            }
            if messages.count < limit {
                AppGroupUserDefaults.User.hasCleanedUpLargeQuoteContent = true
                return true
            }
            rowId = messages.last?.rowId
        }
    }
    
}
