import Foundation
import GRDB

public struct InscriptionCollectionPreview {
    
    public let collectionHash: String
    public let name: String
    public let iconURL: String
    public let description: String?
    public let inscriptionCount: Int
    public let asset: String
    
    public func replacing(name: String, description: String?) -> InscriptionCollectionPreview {
        InscriptionCollectionPreview(
            collectionHash: self.collectionHash,
            name: name,
            iconURL: self.iconURL,
            description: description,
            inscriptionCount: self.inscriptionCount,
            asset: self.asset
        )
    }
    
}

extension InscriptionCollectionPreview: Decodable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case collectionHash = "collection_hash"
        case name
        case iconURL = "icon_url"
        case description
        case inscriptionCount = "inscription_count"
        case asset
    }
    
}
