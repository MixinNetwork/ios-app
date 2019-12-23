import Foundation

public struct UserPreferenceRequest: Codable {
    
    let full_name: String?
    let avatar_base64: String?
    let notification_token: String?
    let receive_message_source: String?
    let accept_conversation_source: String?
    let fiat_currency: String?
    let transfer_notification_threshold: Double?
    let transfer_confirmation_threshold: Double?
    
}

extension UserPreferenceRequest {
    
    static func createRequest(full_name: String? = nil, avatar_base64: String? = nil, notification_token: String? = nil, receive_message_source: String? = nil, accept_conversation_source: String? = nil, fiat_currency: String? = nil, transfer_notification_threshold: Double? = nil, transfer_confirmation_threshold: Double? = nil) -> UserPreferenceRequest {
        return UserPreferenceRequest(full_name: full_name, avatar_base64: avatar_base64, notification_token: notification_token, receive_message_source: receive_message_source, accept_conversation_source: accept_conversation_source, fiat_currency: fiat_currency, transfer_notification_threshold: transfer_notification_threshold, transfer_confirmation_threshold: transfer_confirmation_threshold)
    }
    
}
