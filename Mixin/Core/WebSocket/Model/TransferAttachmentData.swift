import Foundation

struct TransferAttachmentData: Codable {

    var key: Data?
    var digest: Data?
    let attachmentId: String
    @available(*, deprecated, message: "Use mimeType instead.")
    let mineType: String?
    let mimeType: String?
    let width: Int?
    let height: Int?
    let size: Int64
    let thumbnail: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case key
        case digest
        case attachmentId = "attachment_id"
        case mineType = "mine_type"
        case mimeType = "mime_type"
        case width
        case height
        case size
        case thumbnail
        case name
    }

}

extension TransferAttachmentData {

    @available(*, deprecated, message: "Use mimeType instead.")
    func getMimeType() -> String {
        return (mimeType ?? mineType) ?? ""
    }

}
