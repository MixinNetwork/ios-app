import Foundation
import MixinServices

struct DeviceTransferSticker {
    
    let stickerId: String
    let name: String
    let assetUrl: String
    let assetType: String
    let assetWidth: Int
    let assetHeight: Int
    let lastUseAt: String?
    let albumId: String?
    let createdAt: String
    
    init(sticker: Sticker) {
        stickerId = sticker.stickerId
        name = sticker.name
        assetUrl = sticker.assetUrl
        assetType = sticker.assetType
        assetWidth = sticker.assetWidth
        assetHeight = sticker.assetHeight
        lastUseAt = sticker.lastUseAt
        albumId = sticker.albumId
        createdAt = "2017-10-25T00:00:00.000Z"
    }
    
    func toSticker() -> Sticker {
        Sticker(stickerId: stickerId,
                name: name,
                assetUrl: assetUrl,
                assetType: assetType,
                assetWidth: assetWidth,
                assetHeight: assetHeight,
                lastUseAt: lastUseAt,
                albumId: albumId)
    }
    
}

extension DeviceTransferSticker: Codable {
    
    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"
        case name
        case assetUrl = "asset_url"
        case assetType = "asset_type"
        case assetWidth = "asset_width"
        case assetHeight = "asset_height"
        case lastUseAt = "last_used_at"
        case albumId = "album_id"
        case createdAt = "created_at"
    }
    
}
