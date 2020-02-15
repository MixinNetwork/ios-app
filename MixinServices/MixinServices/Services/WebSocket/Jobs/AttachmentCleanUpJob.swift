
import UIKit
import WCDBSwift

class AttachmentCleanUpJob: BaseJob {
    
    let conversationId: String
    var messages: [Message]
    
    init(conversationId: String, categories: [AttachmentContainer.Category] = []) {
        var messageCategories = [MessageCategory]()
        categories.forEach { (category) in
            messageCategories.append(contentsOf: category.messageCategory)
        }
        self.messages = MessageDAO.shared.getMessageOfAttachmentOnDisk(conversationId: conversationId, categories: messageCategories)
        self.conversationId = conversationId
    }

    override func getJobId() -> String {
        "cleanup-attachment-\(conversationId)"
    }

    override func run() throws {
        guard !conversationId.isEmpty else {
            return
        }
        for message in messages {
            guard let category = AttachmentContainer.Category(messageCategory: message.category) else {
                continue
            }
            let url = AttachmentContainer.url(for: category, filename: message.mediaUrl)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
