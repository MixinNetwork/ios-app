import Foundation
import GRDB

public final class InscriptionDAO: UserDatabaseDAO {
    
    private enum SQL {
        
        static let selector = """
            SELECT o.*, c.collection_hash AS \(InscriptionOutput.CodingKeys.collectionHash.rawValue),
                c.name AS \(InscriptionOutput.CodingKeys.collectionName.rawValue),
                c.icon_url AS \(InscriptionOutput.CodingKeys.collectionIconURL.rawValue),
                i.sequence AS \(InscriptionOutput.CodingKeys.inscriptionSequence.rawValue),
                i.content_type AS \(InscriptionOutput.CodingKeys.inscriptionContentType.rawValue),
                i.content_url AS \(InscriptionOutput.CodingKeys.inscriptionContentURL.rawValue)
            FROM outputs o
                LEFT JOIN inscription_items i ON i.inscription_hash = o.inscription_hash
                LEFT JOIN inscription_collections c ON i.collection_hash = c.collection_hash
            WHERE o.state = 'unspent'
        """
        
        static let order = "\nORDER BY o.sequence DESC"
        
    }
    
    public static let shared = InscriptionDAO()
    
    public func inscription(hash: String) -> Inscription? {
        db.select(where: Inscription.column(of: .inscriptionHash) == hash)
    }
    
    public func inscriptionItem(with inscriptionHash: String) -> InscriptionItem? {
        let sql = """
            SELECT o.inscription_hash, c.collection_hash, c.name,
                c.icon_url, i.sequence, i.content_type, i.content_url
            FROM outputs o
                LEFT JOIN inscription_items i ON i.inscription_hash = o.inscription_hash
                LEFT JOIN inscription_collections c ON i.collection_hash = c.collection_hash
            WHERE o.state = 'unspent' AND o.inscription_hash = ?
            LIMIT 1
        """
        return db.select(with: sql, arguments: [inscriptionHash])
    }
    
    public func inscriptionOutput(inscriptionHash hash: String) -> InscriptionOutput? {
        db.select(with: SQL.selector + " AND o.inscription_hash = ?", arguments: [hash])
    }
    
    public func allInscriptionOutputs() -> [InscriptionOutput] {
        db.select(with: SQL.selector + " AND o.inscription_hash IS NOT NULL" + SQL.order)
    }
    
    public func search(keyword: String) -> [InscriptionOutput] {
        let sql = SQL.selector + " AND o.inscription_hash IS NOT NULL AND c.name LIKE ? ESCAPE '/'" + SQL.order
        return db.select(with: sql, arguments: ["%\(keyword.sqlEscaped)%"])
    }
    
    public func save(inscription: Inscription) {
        db.save(inscription)
    }
    
}

extension InscriptionDAO {
    
    public func collectionExists(hash: String) -> Bool {
        db.recordExists(in: InscriptionCollection.self,
                        where: InscriptionCollection.column(of: .collectionHash) == hash)
    }
    
    public func collection(hash: String) -> InscriptionCollection? {
        db.select(where: InscriptionCollection.column(of: .collectionHash) == hash)
    }
    
    public func save(collection: InscriptionCollection) {
        db.save(collection)
    }
    
}
