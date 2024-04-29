import Foundation
import GRDB

public final class InscriptionItem: Inscription {
    
    public let collection: InscriptionCollection?
    
    public init(inscription: Inscription, collection: InscriptionCollection) {
        self.collection = collection
        super.init(type: inscription.type, inscriptionHash: inscription.inscriptionHash, collectionHash: inscription.collectionHash, sequence: inscription.sequence, contentType: inscription.contentType, contentUrl: inscription.contentUrl, occupiedBy: inscription.occupiedBy, occupiedAt: inscription.occupiedAt, createdAt: inscription.createdAt, updatedAt: inscription.updatedAt)
    }
    
    required init(from decoder: any Decoder) throws {
        enum CollectionCodingKeys: String, CodingKey {
            case type = "collection_type"
            case collectionHash = "collection_hash"
            case supply = "collection_supply"
            case unit = "collection_unit"
            case symbol = "collection_symbol"
            case name = "collection_name"
            case iconURL = "collection_icon_url"
            case createdAt = "collection_created_at"
            case updatedAt = "collection_updated_at"
        }
        
        let container = try decoder.container(keyedBy: CollectionCodingKeys.self)
        if let type = try? container.decodeIfPresent(String.self, forKey: .type),
           let collectionHash = try? container.decodeIfPresent(String.self, forKey: .collectionHash),
           let supply = try? container.decodeIfPresent(String.self, forKey: .supply),
           let unit = try? container.decodeIfPresent(String.self, forKey: .unit),
           let symbol = try? container.decodeIfPresent(String.self, forKey: .symbol),
           let name = try? container.decodeIfPresent(String.self, forKey: .name),
           let iconURL = try? container.decodeIfPresent(String.self, forKey: .iconURL),
           let createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt),
           let updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
        {
            self.collection = InscriptionCollection(type: type,
                                                    collectionHash: collectionHash,
                                                    supply: supply,
                                                    unit: unit,
                                                    symbol: symbol,
                                                    name: name,
                                                    iconURL: iconURL,
                                                    createdAt: createdAt,
                                                    updatedAt: updatedAt)
        } else {
            self.collection = nil
        }
        try super.init(from: decoder)
    }
}
