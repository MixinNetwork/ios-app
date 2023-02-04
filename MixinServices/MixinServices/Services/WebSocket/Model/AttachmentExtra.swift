import Foundation

public class AttachmentExtra: Codable {
    
    public let attachmentId: String
    public let createdAt: String
    public let isShareable: Bool?
    
    enum CodingKeys: String, CodingKey {
        case attachmentId = "attachment_id"
        case createdAt = "created_at"
        case isShareable = "shareable"
    }
    
    public init(attachmentId: String, createdAt: String, isShareable: Bool?) {
        self.attachmentId = attachmentId
        self.createdAt = createdAt
        self.isShareable = isShareable
    }
    
}

extension AttachmentExtra {
    
    public class func decode(from string: String) -> AttachmentExtra? {
        if let data = Data(base64Encoded: string), let extra = try? JSONDecoder.default.decode(AttachmentExtra.self, from: data) {
            return extra
        } else if let data = string.data(using: .utf8), let extra = try? JSONDecoder.default.decode(AttachmentExtra.self, from: data) {
            return extra
        } else {
            return nil
        }
    }
    
}
