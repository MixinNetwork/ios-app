import Foundation
import GRDB

public class Inscription: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord, TableRecord, PersistableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case inscriptionHash = "inscription_hash"
        case collectionHash = "collection_hash"
        case sequence
        case contentType = "content_type"
        case contentURL = "content_url"
        case occupiedBy = "occupied_by"
        case occupiedAt = "occupied_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public let inscriptionHash: String
    public let collectionHash: String
    public let sequence: String
    public let contentType: String
    public let contentURL: String
    public let occupiedBy: String?
    public let occupiedAt: String?
    public let createdAt: String
    public let updatedAt: String
    
    public init(
        inscriptionHash: String, collectionHash: String, sequence: String,
        contentType: String, contentURL: String, occupiedBy: String?,
        occupiedAt: String?, createdAt: String, updatedAt: String
    ) {
        self.inscriptionHash = inscriptionHash
        self.collectionHash = collectionHash
        self.sequence = sequence
        self.contentType = contentType
        self.contentURL = contentURL
        self.occupiedBy = occupiedBy
        self.occupiedAt = occupiedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
}
