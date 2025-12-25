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
    public let phone: String?
    public let phoneVerifiedAt: String?
    public let authenticationToken: String
    public let codeID: String
    public let codeURL: String
    public let reputation: Int
    public let createdAt: String
    public let receiveMessageSource: String
    public let acceptConversationSource: String
    public let acceptSearchSource: String
    public let hasPIN: Bool
    public let saltExportedAt: String
    public var hasEmergencyContact: Bool
    public let pinToken: String
    public let fiatCurrency: String
    public let transferNotificationThreshold: Double
    public let transferConfirmationThreshold: Double
    public let tipKey: Data?
    public let tipCounter: UInt64
    public let features: [String]
    public var hasSafe: Bool
    public var salt: String?
    public let membership: User.Membership?
    public let system: System?
    
    public var isAnonymous: Bool {
        if let phone {
            phone.hasPrefix("+" + anonymousCallingCode)
        } else {
            true
        }
    }
    
    public var hasSaltExported: Bool {
        if let date = DateFormatter.iso8601Full.date(from: saltExportedAt) {
            date.timeIntervalSince1970 >= 0
        } else {
            false
        }
    }
    
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
        case phoneVerifiedAt = "phone_verified_at"
        case authenticationToken = "authentication_token"
        case codeID = "code_id"
        case codeURL = "code_url"
        case reputation
        case createdAt = "created_at"
        case receiveMessageSource = "receive_message_source"
        case acceptConversationSource = "accept_conversation_source"
        case acceptSearchSource = "accept_search_source"
        case hasPIN = "has_pin"
        case saltExportedAt = "salt_exported_at"
        case hasEmergencyContact = "has_emergency_contact"
        case pinToken = "pin_token"
        case fiatCurrency = "fiat_currency"
        case transferNotificationThreshold = "transfer_notification_threshold"
        case transferConfirmationThreshold = "transfer_confirmation_threshold"
        case tipKey = "tip_key_base64"
        case tipCounter = "tip_counter"
        case features
        case hasSafe = "has_safe"
        case salt = "salt_base64"
        case membership
        case system
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
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        phoneVerifiedAt = try container.decodeIfPresent(String.self, forKey: .phoneVerifiedAt)
        authenticationToken = try container.decodeIfPresent(String.self, forKey: .authenticationToken) ?? ""
        codeID = try container.decodeIfPresent(String.self, forKey: .codeID) ?? ""
        codeURL = try container.decodeIfPresent(String.self, forKey: .codeURL) ?? ""
        reputation = try container.decodeIfPresent(Int.self, forKey: .reputation) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        receiveMessageSource = try container.decodeIfPresent(String.self, forKey: .receiveMessageSource) ?? ""
        acceptConversationSource = try container.decodeIfPresent(String.self, forKey: .acceptConversationSource) ?? ""
        acceptSearchSource = try container.decodeIfPresent(String.self, forKey: .acceptSearchSource) ?? ""
        hasPIN = try container.decodeIfPresent(Bool.self, forKey: .hasPIN) ?? false
        saltExportedAt = try container.decodeIfPresent(String.self, forKey: .saltExportedAt) ?? ""
        hasEmergencyContact = try container.decodeIfPresent(Bool.self, forKey: .hasEmergencyContact) ?? false
        pinToken = try container.decodeIfPresent(String.self, forKey: .pinToken) ?? ""
        fiatCurrency = try container.decodeIfPresent(String.self, forKey: .fiatCurrency) ?? ""
        transferNotificationThreshold = try container.decodeIfPresent(Double.self, forKey: .transferNotificationThreshold) ?? 0
        transferConfirmationThreshold = try container.decodeIfPresent(Double.self, forKey: .transferConfirmationThreshold) ?? 0
        if let encoded = try container.decodeIfPresent(String.self, forKey: .tipKey), let key = Data(base64URLEncoded: encoded), !key.isEmpty {
            tipKey = key
        } else if let key = try container.decodeIfPresent(Data.self, forKey: .tipKey), !key.isEmpty {
            tipKey = key
        } else {
            tipKey = nil
        }
        tipCounter = try container.decodeIfPresent(UInt64.self, forKey: .tipCounter) ?? 0
        features = try container.decodeIfPresent([String].self, forKey: .features) ?? []
        hasSafe = try container.decodeIfPresent(Bool.self, forKey: .hasSafe) ?? false
        salt = try container.decodeIfPresent(String.self, forKey: .salt)
        membership = try container.decodeIfPresent(User.Membership.self, forKey: .membership)
        system = try? container.decodeIfPresent(System.self, forKey: .system)
    }
    
}

extension Account {
    
    public struct System: Codable {
        public let messenger: Messenger
    }
    
    public struct Messenger: Codable {
        public let version: SemanticVersion
    }
    
}
