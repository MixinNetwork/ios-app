import Foundation

public struct InscriptionItem {
    
    public let collectionHash: String
    public let collectionName: String
    public let collectionIconURL: String
    public let inscriptionHash: String
    public let sequence: UInt64
    public let contentType: String
    public let contentURL: String
    
    public var collectionSequenceRepresentation: String {
        collectionName + " " + sequenceRepresentation
    }
    
    public var sequenceRepresentation: String {
        "#\(sequence)"
    }
    
    public var shareLink: String {
        "https://mixin.space/inscriptions/\(inscriptionHash)"
    }
    
    public init(collection: InscriptionCollection, inscription: Inscription) {
        collectionHash      = collection.collectionHash
        collectionName      = collection.name
        collectionIconURL   = collection.iconURL
        inscriptionHash = inscription.inscriptionHash
        sequence        = inscription.sequence
        contentType     = inscription.contentType
        contentURL      = inscription.contentURL
    }
    
    init(
        collectionHash: String, collectionName: String,
        collectionIconURL: String, inscriptionHash: String,
        sequence: UInt64, contentType: String, contentURL: String
    ) {
        self.collectionHash = collectionHash
        self.collectionName = collectionName
        self.collectionIconURL = collectionIconURL
        self.inscriptionHash = inscriptionHash
        self.sequence = sequence
        self.contentType = contentType
        self.contentURL = contentURL
    }
    
}

extension InscriptionItem: Codable, MixinFetchableRecord {
    
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

extension InscriptionItem: InstanceInitializable {
    
    init?(messageContent: String?) {
        guard let data = messageContent?.data(using: .utf8) else {
            return nil
        }
        guard let instance = try? JSONDecoder.default.decode(Self.self, from: data) else {
            return nil
        }
        self.init(instance: instance)
    }
    
    public func asMessageContent() -> String? {
        guard let data = try? JSONEncoder.default.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
}

extension InscriptionItem: InscriptionContent {
    
    public var inscriptionContentType: String? {
        contentType
    }
    
    public var inscriptionContentURL: String? {
        contentURL
    }
    
}

extension InscriptionItem {
    
    public static func fetchAndSave(inscriptionHash: String) async throws -> InscriptionItem {
        let inscription = try await InscriptionAPI.inscription(inscriptionHash: inscriptionHash)
        InscriptionDAO.shared.save(inscription: inscription)
        let collection = try await InscriptionAPI.collection(collectionHash: inscription.collectionHash)
        InscriptionDAO.shared.save(collection: collection)
        return InscriptionItem(collection: collection, inscription: inscription)
    }
    
}
