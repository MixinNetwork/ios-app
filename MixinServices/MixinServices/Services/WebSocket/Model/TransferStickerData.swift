import Foundation

public struct TransferStickerData: Codable {
    
    public let stickerId: String
    
    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"
    }
    
    public init(stickerId: String) {
        self.stickerId = stickerId
    }
    
}
