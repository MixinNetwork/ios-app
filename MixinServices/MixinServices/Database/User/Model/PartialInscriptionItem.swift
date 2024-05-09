import Foundation

public struct PartialInscriptionItem {
    
    public let collectionHash: String?
    public let collectionName: String?
    public let collectionIconURL: String?
    public let inscriptionHash: String
    public let sequence: UInt64?
    public let contentType: String?
    public let contentURL: String?
    
}

extension PartialInscriptionItem: Decodable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case collectionHash = "collection_hash"
        case collectionName = "name"
        case collectionIconURL = "icon_url"
        case inscriptionHash = "inscription_hash"
        case sequence
        case contentType = "content_type"
        case contentURL = "content_url"
    }
    
}

extension PartialInscriptionItem {
    
    public func asInscriptionItem() -> InscriptionItem? {
        guard
            let collectionHash, let collectionName, let collectionIconURL,
            let sequence, let contentType, let contentURL
        else {
            return nil
        }
        return InscriptionItem(
            collectionHash: collectionHash, collectionName: collectionName,
            collectionIconURL: collectionIconURL, inscriptionHash: inscriptionHash,
            sequence: sequence, contentType: contentType, contentURL: contentURL
        )
    }
    
}
