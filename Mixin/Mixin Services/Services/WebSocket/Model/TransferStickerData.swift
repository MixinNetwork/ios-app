import Foundation

public struct TransferStickerData: Codable {
    
    public let stickerId: String?
    public let name: String?
    public let albumId: String?
    
    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"
        case name
        case albumId = "album_id"
    }
    
    public init(stickerId: String?, name: String?, albumId: String?) {
        self.stickerId = stickerId
        self.name = name
        self.albumId = albumId
    }
    
}
