import Foundation

struct BlazeMessageData: Codable {

    let conversationId: String
    var userId: String
    var messageId: String
    let category: String
    let data: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let source: String
    let quoteMessageId: String
    let representativeId: String
    var sessionId: String? = nil
    var primitiveId: String? = nil

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
        case sessionId = "session_id"
        case primitiveId = "primitive_id"
    }
}

extension BlazeMessageData {

    func getSenderId() -> String {
        guard !representativeId.isEmpty else {
            return userId
        }
        return representativeId
    }

    var isSessionMessage: Bool {
        return userId == AccountAPI.shared.accountUserId && sessionId != nil
    }

}
