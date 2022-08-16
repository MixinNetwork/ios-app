import Foundation

public enum ReceiveMessageSource: String {
    case everybody = "EVERYBODY"
    case contacts = "CONTACTS"
}

public enum AcceptConversationSource: String {
    case everybody = "EVERYBODY"
    case contacts = "CONTACTS"
}

public enum AcceptSearchSource: String {
    case everybody = "EVERYBODY"
    case contacts = "CONTACTS"
    case nobody = "NOBODY"
}

public struct Account {
    
    public let userID: String
    public let sessionID: String
    public let type: String
    public let identityNumber: String
    public let fullName: String
    public let biography: String
    public let avatarURL: String
    public let phone: String
    public let authenticationToken: String
    public let codeID: String
    public let codeURL: String
    public let reputation: Int
    public let createdAt: String
    public let receiveMessageSource: String
    public let acceptConversationSource: String
    public let acceptSearchSource: String
    public let hasPIN: Bool
    public var hasEmergencyContact: Bool
    public let pinToken: String
    public let fiatCurrency: String
    public let transferNotificationThreshold: Double
    public let transferConfirmationThreshold: Double
    
}

extension Account: Codable {
    
    public enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case sessionID = "session_id"
        case type
        case identityNumber = "identity_number"
        case fullName = "full_name"
        case biography
        case avatarURL = "avatar_url"
        case phone
        case authenticationToken = "authentication_token"
        case codeID = "code_id"
        case codeURL = "code_url"
        case reputation
        case createdAt = "created_at"
        case receiveMessageSource = "receive_message_source"
        case acceptConversationSource = "accept_conversation_source"
        case acceptSearchSource = "accept_search_source"
        case hasPIN = "has_pin"
        case hasEmergencyContact = "has_emergency_contact"
        case pinToken = "pin_token"
        case fiatCurrency = "fiat_currency"
        case transferNotificationThreshold = "transfer_notification_threshold"
        case transferConfirmationThreshold = "transfer_confirmation_threshold"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        identityNumber = try container.decode(String.self, forKey: .identityNumber)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        biography = try container.decodeIfPresent(String.self, forKey: .biography) ?? ""
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        authenticationToken = try container.decodeIfPresent(String.self, forKey: .authenticationToken) ?? ""
        codeID = try container.decodeIfPresent(String.self, forKey: .codeID) ?? ""
        codeURL = try container.decodeIfPresent(String.self, forKey: .codeURL) ?? ""
        reputation = try container.decodeIfPresent(Int.self, forKey: .reputation) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        receiveMessageSource = try container.decodeIfPresent(String.self, forKey: .receiveMessageSource) ?? ""
        acceptConversationSource = try container.decodeIfPresent(String.self, forKey: .acceptConversationSource) ?? ""
        acceptSearchSource = try container.decodeIfPresent(String.self, forKey: .acceptSearchSource) ?? ""
        hasPIN = try container.decodeIfPresent(Bool.self, forKey: .hasPIN) ?? false
        hasEmergencyContact = try container.decodeIfPresent(Bool.self, forKey: .hasEmergencyContact) ?? false
        pinToken = try container.decodeIfPresent(String.self, forKey: .pinToken) ?? ""
        fiatCurrency = try container.decodeIfPresent(String.self, forKey: .fiatCurrency) ?? ""
        transferNotificationThreshold = try container.decodeIfPresent(Double.self, forKey: .transferNotificationThreshold) ?? 0
        transferConfirmationThreshold = try container.decodeIfPresent(Double.self, forKey: .transferConfirmationThreshold) ?? 0
    }
    
}
