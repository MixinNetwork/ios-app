import Foundation

struct UserRequest: Codable {
    let full_name: String?
    let avatar_base64: String?
    let notification_token: String?
    let receive_message_source: String?
    let accept_conversation_source: String?
}
