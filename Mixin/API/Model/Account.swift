import Foundation

struct Account: Encodable {
    
    let user_id: String
    let session_id: String
    let type: String
    let identity_number: String
    let full_name: String
    let biography: String
    let avatar_url: String
    let phone: String
    let authentication_token: String
    let code_id: String
    let code_url: String
    let reputation: Int
    let created_at: String
    let receive_message_source: String
    let accept_conversation_source: String
    let has_pin: Bool
    var has_emergency_contact: Bool
    let pin_token: String
    let fiat_currency: String
    let transfer_notification_threshold: Double
    let transfer_confirmation_threshold: Double
}

extension Account: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decode(String.self, forKey: .user_id)
        session_id = try container.decode(String.self, forKey: .session_id)
        identity_number = try container.decode(String.self, forKey: .identity_number)
        type = container.getString(key: .type)
        full_name = container.getString(key: .full_name)
        biography = container.getString(key: .biography)
        avatar_url = container.getString(key: .avatar_url)
        phone = container.getString(key: .phone)
        authentication_token = container.getString(key: .authentication_token)
        code_id = container.getString(key: .code_id)
        reputation = container.getInt(key: .reputation)
        created_at = container.getString(key: .created_at)
        receive_message_source = container.getString(key: .receive_message_source)
        accept_conversation_source = container.getString(key: .accept_conversation_source)
        has_pin = container.getBool(key: .has_pin)
        has_emergency_contact = container.getBool(key: .has_emergency_contact)
        code_url = container.getString(key: .code_url)
        pin_token = container.getString(key: .pin_token)
        fiat_currency = container.getString(key: .fiat_currency)
        transfer_notification_threshold = container.getDouble(key: .transfer_notification_threshold)
        transfer_confirmation_threshold = container.getDouble(key: .transfer_confirmation_threshold)
    }

}

enum ReceiveMessageSource: String {
    case everybody = "EVERYBODY"
    case contacts = "CONTACTS"
}

enum AcceptConversationSource: String {
    case everybody = "EVERYBODY"
    case contacts = "CONTACTS"
}
