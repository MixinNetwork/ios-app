import Foundation

public struct AttachmentResponse: Codable {
    
    let attachmentId: String
    let uploadUrl: String?
    let viewUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case attachmentId = "attachment_id"
        case uploadUrl = "upload_url"
        case viewUrl = "view_url"
    }
    
}
