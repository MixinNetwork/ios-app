import Foundation

struct CollectibleToken: Codable {
    
    let type: String
    let tokenId: String
    let groupKey: String
    let tokenKey: String
    let createdAt: String
    let meta: Meta
    
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
    
    struct Meta: Codable {
        let groupName: String
        let tokenName: String
        let description: String
        let iconUrl: String
        let mediaUrl: String
        let mime: String
        let hash: String
        
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
