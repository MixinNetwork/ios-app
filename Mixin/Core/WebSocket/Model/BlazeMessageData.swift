import Foundation

struct BlazeMessageData: Codable {

    let conversationId: String
    let userId: String
    var messageId: String
    let category: String
    let data: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let source: String
    let quoteMessageId: String?
    let representativeId: String?

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case messageId = "message_id"
        case category
        case data
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case source
        case quoteMessageId = "quote_message_id"
        case representativeId = "representative_id"
    }
}

extension BlazeMessageData {

    func getSenderId() -> String {
        guard let rId = representativeId, !rId.isEmpty else {
            return userId
        }
        return rId
    }

}
