import UIKit

public class AttachmentCleanUpJob: BaseJob {
    
    let conversationId: String
    let mediaUrls: [String: String]
    let transcriptIds: [String]
    
    public init(conversationId: String, mediaUrls: [String: String], transcriptIds: [String]) {
        self.conversationId = conversationId
        self.mediaUrls = mediaUrls
        self.transcriptIds = transcriptIds
    }
    
    override open func getJobId() -> String {
        "cleanup-attachment-\(conversationId)"
    }
    
    override open func run() throws {
        let hasContent = !mediaUrls.isEmpty || !transcriptIds.isEmpty
        guard !conversationId.isEmpty && hasContent else {
            return
        }
        for (mediaUrl, category) in mediaUrls {
            AttachmentContainer.removeMediaFiles(mediaUrl: mediaUrl, category: category)
        }
        transcriptIds.forEach(AttachmentContainer.removeAll(transcriptId:))
        NotificationCenter.default.post(onMainThread: storageUsageDidChangeNotification, object: self)
    }
    
}
