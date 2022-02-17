import Foundation

public struct CollectibleToken: Codable {
    
    public let type: String
    public let tokenId: String
    public let groupKey: String
    public let tokenKey: String
    public let createdAt: String
    public let meta: Meta
    
    enum CodingKeys: String, CodingKey {
        case type
        case tokenId = "token_id"
        case groupKey = "group"
        case tokenKey = "token"
        case createdAt = "created_at"
        case meta
    }
    
}

extension CollectibleToken {
    
    public struct Meta: Codable {
        public let groupName: String
        public let tokenName: String
        public let description: String
        public let iconUrl: String
        public let mediaUrl: String
        public let mime: String
        public let hash: String
        
        enum CodingKeys: String, CodingKey {
            case groupName = "group"
            case tokenName = "name"
            case description
            case iconUrl = "icon_url"
            case mediaUrl = "media_url"
            case mime
            case hash
        }
    }
    
}
