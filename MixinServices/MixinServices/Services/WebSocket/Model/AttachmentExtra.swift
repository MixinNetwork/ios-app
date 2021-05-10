import Foundation

public class AttachmentExtra: Codable {
    
    public let attachmentId: String
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case attachmentId = "attachment_id"
        case createdAt = "created_at"
    }
    
    public init(attachmentId: String, createdAt: String) {
        self.attachmentId = attachmentId
        self.createdAt = createdAt
    }
    
}
