import Foundation
import GRDB

public final class InscriptionDAO: UserDatabaseDAO {
    
    private enum SQL {
        static let selector = """
            SELECT c.collection_hash, c.name, c.icon_url, i.inscription_hash, i.sequence, i.content_type, i.content_url
            FROM (SELECT inscription_hash FROM outputs WHERE state = 'unspent' AND inscription_hash IS NOT NULL) o
                LEFT JOIN inscription_items i ON i.inscription_hash = o.inscription_hash
                LEFT JOIN inscription_collections c ON i.collection_hash = c.collection_hash
            ORDER BY i.updated_at DESC
        """
    }
    
    public static let shared = InscriptionDAO()
    
    public func inscription(hash: String) -> Inscription? {
        db.select(where: Inscription.column(of: .inscriptionHash) == hash)
    }
    
    public func partialInscriptionItem(with inscriptionHash: String) -> PartialInscriptionItem? {
        let sql = "\(SQL.selector) WHERE o.inscription_hash = ?"
        return db.select(with: sql, arguments: [inscriptionHash])
    }
    
    public func inscriptionItem(with inscriptionHash: String) -> InscriptionItem? {
        partialInscriptionItem(with: inscriptionHash)?.asInscriptionItem()
    }
    
    public func allPartialInscriptions() -> [PartialInscriptionItem] {
        db.select(with: SQL.selector)
    }
    
    public func search(keyword: String, limit: Int?) -> [InscriptionItem] {
        return []
    }
    
    public func inscriptionExists(inscriptionHash: String) -> Bool {
        db.recordExists(in: Inscription.self, where: Inscription.column(of: .inscriptionHash) == inscriptionHash)
    }
    
    public func save(inscription: Inscription) {
        db.save(inscription)
    }
    
}

extension InscriptionDAO {
    
    public func collection(hash: String) -> InscriptionCollection? {
        db.select(where: InscriptionCollection.column(of: .collectionHash) == hash)
    }
    
    public func save(collection: InscriptionCollection) {
        db.save(collection)
    }
    
}
