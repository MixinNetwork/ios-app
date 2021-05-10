import Foundation

public struct TransferAttachmentData: Encodable {
    
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
    public let createdAt: String?
    
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
        case createdAt = "created_at"
    }
    
    public init(key: Data?, digest: Data?, attachmentId: String, mimeType: String?, width: Int?, height: Int?, size: Int64, thumbnail: String?, name: String?, duration: Int64?, waveform: Data?, createdAt: String?) {
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
        self.createdAt = createdAt
    }
    
}

extension TransferAttachmentData: Decodable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(Data.self, forKey: .key)
        digest = try container.decodeIfPresent(Data.self, forKey: .digest)
        attachmentId = try container.decode(String.self, forKey: .attachmentId)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        width = try Self.safeDecodeInt(container: container, key: .width)
        height = try Self.safeDecodeInt(container: container, key: .height)
        size = try container.decode(Int64.self, forKey: .size)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        duration = try Self.safeDecodeInt64(container: container, key: .duration)
        waveform = try container.decodeIfPresent(Data.self, forKey: .waveform)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    private static func safeDecodeInt(container: KeyedDecodingContainer<CodingKeys>, key: KeyedDecodingContainer<CodingKeys>.Key) throws -> Int? {
        do {
            return try container.decodeIfPresent(Int.self, forKey: key)
        } catch {
            Logger.write(error: error)
        }
        do {
            return Int(try container.decode(Float.self, forKey: key))
        } catch {
            Logger.write(error: error)
        }
        return try container.decode(String.self, forKey: key).intValue
    }

    private static func safeDecodeInt64(container: KeyedDecodingContainer<CodingKeys>, key: KeyedDecodingContainer<CodingKeys>.Key) throws -> Int64? {
        do {
            return try container.decodeIfPresent(Int64.self, forKey: key)
        } catch {
            Logger.write(error: error)
        }
        do {
            return Int64(try container.decode(Float.self, forKey: key))
        } catch {
            Logger.write(error: error)
        }
        return try container.decode(String.self, forKey: key).int64Value
    }
}
