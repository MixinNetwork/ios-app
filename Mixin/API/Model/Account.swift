import Foundation

struct Account: Encodable {
    let user_id: String
    let session_id: String
    let type: String
    let identity_number: String
    let full_name: String
    let avatar_url: String
    let phone: String
    let authentication_token: String
    let invitation_code: String
    let consumed_count: Int
    let code_id: String
    let code_url: String
    let reputation: Int
    let created_at: String
    let receive_message_source: String
    let accept_conversation_source: String
    let has_pin: Bool
    let pin_token: String
    
    init(withAccount old: Account, receiveMessageSource: ReceiveMessageSource) {
        self.user_id = old.user_id
        self.session_id = old.session_id
        self.type = old.type
        self.identity_number = old.identity_number
        self.full_name = old.full_name
        self.avatar_url = old.avatar_url
        self.phone = old.phone
        self.authentication_token = old.authentication_token
        self.invitation_code = old.invitation_code
        self.consumed_count = old.consumed_count
        self.code_id = old.code_id
        self.reputation = old.reputation
        self.created_at = old.created_at
        self.receive_message_source = receiveMessageSource.rawValue
        self.accept_conversation_source = old.accept_conversation_source
        self.has_pin = old.has_pin
        self.code_url = old.code_url
        self.pin_token = old.pin_token
    }
    
    init(withAccount old: Account, acceptConversationSource: AcceptConversationSource) {
        self.user_id = old.user_id
        self.session_id = old.session_id
        self.type = old.type
        self.identity_number = old.identity_number
        self.full_name = old.full_name
        self.avatar_url = old.avatar_url
        self.phone = old.phone
        self.authentication_token = old.authentication_token
        self.invitation_code = old.invitation_code
        self.consumed_count = old.consumed_count
        self.code_id = old.code_id
        self.reputation = old.reputation
        self.created_at = old.created_at
        self.receive_message_source = old.receive_message_source
        self.accept_conversation_source = acceptConversationSource.rawValue
        self.has_pin = old.has_pin
        self.code_url = old.code_url
        self.pin_token = old.pin_token
    }
    
    init(withAccount old: Account, phone: String) {
        self.user_id = old.user_id
        self.session_id = old.session_id
        self.type = old.type
        self.identity_number = old.identity_number
        self.full_name = old.full_name
        self.avatar_url = old.avatar_url
        self.phone = phone
        self.authentication_token = old.authentication_token
        self.invitation_code = old.invitation_code
        self.consumed_count = old.consumed_count
        self.code_id = old.code_id
        self.reputation = old.reputation
        self.created_at = old.created_at
        self.receive_message_source = old.receive_message_source
        self.accept_conversation_source = old.accept_conversation_source
        self.has_pin = old.has_pin
        self.code_url = old.code_url
        self.pin_token = old.pin_token
    }
    
}

extension Account: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decode(String.self, forKey: .user_id)
        session_id = try container.decode(String.self, forKey: .session_id)
        identity_number = try container.decode(String.self, forKey: .identity_number)
        type = container.getString(key: .type)
        full_name = container.getString(key: .full_name)
        avatar_url = container.getString(key: .avatar_url)
        phone = container.getString(key: .phone)
        authentication_token = container.getString(key: .authentication_token)
        invitation_code = container.getString(key: .invitation_code)
        consumed_count = container.getInt(key: .consumed_count)
        code_id = container.getString(key: .code_id)
        reputation = container.getInt(key: .reputation)
        created_at = container.getString(key: .created_at)
        receive_message_source = container.getString(key: .receive_message_source)
        accept_conversation_source = container.getString(key: .accept_conversation_source)
        has_pin = container.getBool(key: .has_pin)
        code_url = container.getString(key: .code_url)
        pin_token = container.getString(key: .pin_token)
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
