import Foundation

struct TransferStickerData: Codable {

    let stickerId: String?
    let name: String?
    let albumId: String?

    enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"
        case name
        case albumId = "album_id"
    }

}
