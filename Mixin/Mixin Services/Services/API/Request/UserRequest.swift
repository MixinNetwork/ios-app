import Foundation

public struct UserPreferenceRequest: Codable {
    
    public let full_name: String?
    public let avatar_base64: String?
    public let notification_token: String?
    public let receive_message_source: String?
    public let accept_conversation_source: String?
    public let fiat_currency: String?
    public let transfer_notification_threshold: Double?
    public let transfer_confirmation_threshold: Double?
    
    public init(full_name: String? = nil, avatar_base64: String? = nil, notification_token: String? = nil, receive_message_source: String? = nil, accept_conversation_source: String? = nil, fiat_currency: String? = nil, transfer_notification_threshold: Double? = nil, transfer_confirmation_threshold: Double? = nil) {
        self.full_name = full_name
        self.avatar_base64 = avatar_base64
        self.notification_token = notification_token
        self.receive_message_source = receive_message_source
        self.accept_conversation_source = accept_conversation_source
        self.fiat_currency = fiat_currency
        self.transfer_notification_threshold = transfer_notification_threshold
        self.transfer_confirmation_threshold = transfer_confirmation_threshold
    }
    
}
