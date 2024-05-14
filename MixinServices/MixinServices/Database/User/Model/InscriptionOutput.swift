import Foundation

public struct InscriptionOutput {
    
    public let output: Output
    public let inscription: InscriptionItem?
    
    public var inscriptionHash: String {
        // Nullability is ensured by SQL
        output.inscriptionHash!
    }
    
    public func replacing(inscription: InscriptionItem) -> InscriptionOutput {
        InscriptionOutput(output: output, inscription: inscription)
    }
    
}

extension InscriptionOutput: Decodable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case collectionHash = "collection_hash"
        case collectionName = "collection_name"
        case collectionIconURL = "collection_icon_url"
        case inscriptionHash = "inscription_hash"
        case inscriptionSequence = "inscription_sequence"
        case inscriptionContentType = "inscription_content_type"
        case inscriptionContentURL = "inscription_content_url"
    }
    
    public init(from decoder: any Decoder) throws {
        let output = try Output(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let inscription: InscriptionItem? = if let inscriptionHash = output.inscriptionHash,
            let collectionHash = try container.decodeIfPresent(String.self, forKey: .collectionHash),
            let collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName),
            let collectionIconURL = try container.decodeIfPresent(String.self, forKey: .collectionIconURL),
            let inscriptionSequence = try container.decodeIfPresent(UInt64.self, forKey: .inscriptionSequence),
            let inscriptionContentType = try container.decodeIfPresent(String.self, forKey: .inscriptionContentType),
            let inscriptionContentURL = try container.decodeIfPresent(String.self, forKey: .inscriptionContentURL)
        {
            InscriptionItem(collectionHash: collectionHash,
                            collectionName: collectionName,
                            collectionIconURL: collectionIconURL,
                            inscriptionHash: inscriptionHash,
                            sequence: inscriptionSequence,
                            contentType: inscriptionContentType,
                            contentURL: inscriptionContentURL)
        } else {
            nil
        }
        
        self.output = output
        self.inscription = inscription
    }
    
}
