import Foundation

struct NonFungibleToken: Codable {
    
    let type: String
    let tokenId: String
    let chainId: String
    let classKey: String
    let groupKey: String
    let tokenKey: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case type
        case tokenId = "token_id"
        case chainId = "chain_id"
        case classKey = "class"
        case groupKey = "group"
        case tokenKey = "token"
        case createdAt = "created_at"
    }
    
}
