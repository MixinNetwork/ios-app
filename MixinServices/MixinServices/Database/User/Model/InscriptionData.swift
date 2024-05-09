import Foundation

public struct InscriptionData {
    
    public let collectionHash: String
    public let name: String
    public let iconURL: String
    public let inscriptionHash: String
    public let sequence: UInt64
    public let contentType: String
    public let contentURL: String
    
    init(collection: InscriptionCollection, inscription: Inscription) {
        collectionHash  = collection.collectionHash
        name            = collection.name
        iconURL         = collection.iconURL
        inscriptionHash = inscription.inscriptionHash
        sequence        = inscription.sequence
        contentType     = inscription.contentType
        contentURL      = inscription.contentURL
    }
    
}

extension InscriptionData: Codable {
    
    enum CodingKeys: String, CodingKey {
        case collectionHash = "collection_hash"
        case name
        case iconURL = "icon_url"
        case inscriptionHash = "inscription_hash"
        case sequence
        case contentType = "content_type"
        case contentURL = "content_url"
    }
    
}

extension InscriptionData: InstanceInitializable {
    
    init?(messageContent: String) {
        guard let data = messageContent.data(using: .utf8) else {
            return nil
        }
        guard let instance = try? JSONDecoder.default.decode(Self.self, from: data) else {
            return nil
        }
        self.init(instance: instance)
    }
    
    func asMessageContent() -> String? {
        guard let data = try? JSONEncoder.default.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
}
