import Foundation

struct TransferStickerData: Codable {

    let name: String
    let albumId: String

    enum CodingKeys: String, CodingKey {
        case name
        case albumId = "album_id"
    }

}
