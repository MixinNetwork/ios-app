import Foundation

public struct TransferAttachmentData: Codable {
    
    public var key: Data?
    public var digest: Data?
    public let attachmentId: String
    public let mimeType: String?
    public let width: Int?
    public let height: Int?
    public let size: Int64
    public let thumbnail: String?
    public let name: String?
    public let duration: Int64?
    public let waveform: Data?
    
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
    
    public init(key: Data?, digest: Data?, attachmentId: String, mimeType: String?, width: Int?, height: Int?, size: Int64, thumbnail: String?, name: String?, duration: Int64?, waveform: Data?) {
        self.key = key
        self.digest = digest
        self.attachmentId = attachmentId
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.size = size
        self.thumbnail = thumbnail
        self.name = name
        self.duration = duration
        self.waveform = waveform
    }
    
}
