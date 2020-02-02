import Foundation

public struct StickerResponse: Codable {
    
    public let stickerId: String
    public let name: String
    public let assetUrl: String
    public let assetType: String
    public let assetWidth: Int
    public let assetHeight: Int
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"
        case name
        case assetUrl = "asset_url"
        case assetType = "asset_type"
        case assetWidth = "asset_width"
        case assetHeight = "asset_height"
        case createdAt = "created_at"
    }
    
}
