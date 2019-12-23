import Foundation

public struct TransferAttachmentData: Codable {

    var key: Data?
    var digest: Data?
    let attachmentId: String
    let mimeType: String?
    let width: Int?
    let height: Int?
    let size: Int64
    let thumbnail: String?
    let name: String?
    let duration: Int64?
    let waveform: Data?

    enum CodingKeys: String, CodingKey {
        case key
        case digest
        case attachmentId = "attachment_id"
        case mimeType = "mime_type"
        case width
        case height
        case size
        case thumbnail
        case name
        case duration
        case waveform
    }

}
