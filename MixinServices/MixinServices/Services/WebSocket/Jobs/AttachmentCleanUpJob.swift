
import UIKit
import WCDBSwift

public class AttachmentCleanUpJob: BaseJob {

    let conversationId: String
    let mediaUrls: [String: String]

    public init(conversationId: String, mediaUrls: [String: String]) {
        self.conversationId = conversationId
        self.mediaUrls = mediaUrls
    }

    override open func getJobId() -> String {
        "cleanup-attachment-\(conversationId)"
    }

    override open func run() throws {
        guard !conversationId.isEmpty, mediaUrls.count > 0 else {
            return
        }

        for (mediaUrl, category) in mediaUrls {
            AttachmentContainer.removeMediaFiles(mediaUrl: mediaUrl, category: category)
        }
    }
}
