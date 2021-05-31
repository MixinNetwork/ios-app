import UIKit

public class AttachmentCleanUpJob: BaseJob {
    
    let conversationId: String
    let mediaUrls: [String: String]
    let transcriptMessageIds: [String]
    
    public init(
        conversationId: String,
        mediaUrls: [String: String],
        transcriptMessageIds: [String]
    ) {
        self.conversationId = conversationId
        self.mediaUrls = mediaUrls
        self.transcriptMessageIds = transcriptMessageIds
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
        for id in transcriptMessageIds {
            AttachmentContainer.removeAll(transcriptId: id)
        }
        NotificationCenter.default.post(onMainThread: storageUsageDidChangeNotification, object: self)
    }
    
}
