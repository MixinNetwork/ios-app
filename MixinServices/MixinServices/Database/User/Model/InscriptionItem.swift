import Foundation

public final class InscriptionItem {
    
    public let collectionHash: String
    public let collectionName: String
    public let collectionIconURL: String
    public let inscriptionHash: String
    public let sequence: UInt64
    public let contentType: String
    public let contentURL: String
    public let traits: String?
    public let owner: String?
    
    public lazy var nameValueTraits: [NameValueTrait]? = {
        guard let traits, let data = traits.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder.default.decode([NameValueTrait].self, from: data)
    }()
    
    public var collectionSequenceRepresentation: String {
        collectionName + " " + sequenceRepresentation
    }
    
    public var sequenceRepresentation: String {
        "#\(sequence)"
    }
    
    public var shareLink: String {
        "https://mixin.one/inscriptions/\(inscriptionHash)"
    }
    
    public init(collection: InscriptionCollection, inscription: Inscription) {
        collectionHash      = collection.collectionHash
        collectionName      = collection.name
        collectionIconURL   = collection.iconURL
        inscriptionHash = inscription.inscriptionHash
        sequence        = inscription.sequence
        contentType     = inscription.contentType
        contentURL      = inscription.contentURL
        traits          = inscription.traits
        owner           = inscription.owner
    }
    
    init(
        collectionHash: String, collectionName: String,
        collectionIconURL: String, inscriptionHash: String,
        sequence: UInt64, contentType: String, contentURL: String,
        traits: String?, owner: String?
    ) {
        self.collectionHash = collectionHash
        self.collectionName = collectionName
        self.collectionIconURL = collectionIconURL
        self.inscriptionHash = inscriptionHash
        self.sequence = sequence
        self.contentType = contentType
        self.contentURL = contentURL
        self.traits = traits
        self.owner = owner
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
        case traits
        case owner
    }
    
}

extension InscriptionItem: InstanceInitializable {
    
    convenience init?(messageContent: String?) {
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

extension InscriptionItem: InscriptionContentProvider {
    
    public var inscriptionCollectionIconURL: String? {
        collectionIconURL
    }
    
    public var inscriptionContentType: String? {
        contentType
    }
    
    public var inscriptionContentURL: String? {
        contentURL
    }
    
}

extension InscriptionItem {
    
    public static func fetchAndSave(inscriptionHash: String) -> Result<InscriptionItem, MixinAPIError> {
        assert(!Thread.isMainThread)
        let inscription: Inscription
        switch InscriptionAPI.inscription(inscriptionHash: inscriptionHash) {
        case .success(let i):
            inscription = i
        case .failure(let error):
            return .failure(error)
        }
        InscriptionDAO.shared.save(inscription: inscription)
        
        let collection: InscriptionCollection
        if let c = InscriptionDAO.shared.collection(hash: inscription.collectionHash) {
            collection = c
        } else {
            switch InscriptionAPI.collection(collectionHash: inscription.collectionHash) {
            case .success(let c):
                collection = c
                InscriptionDAO.shared.save(collection: collection)
            case .failure(let error):
                return .failure(error)
            }
        }
        
        let item = InscriptionItem(collection: collection, inscription: inscription)
        return .success(item)
    }
    
}

extension InscriptionItem {
    
    public struct NameValueTrait: Decodable {
        public let name: String
        public let value: String
    }
    
}
