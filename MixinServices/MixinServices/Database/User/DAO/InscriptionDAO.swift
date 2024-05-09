import Foundation
import GRDB

public final class InscriptionDAO: UserDatabaseDAO {
    
    private enum SQL {
        static let selector = """
        SELECT i.*, ic.name AS collection_name, ic.icon_url AS collection_icon_url,
            t.symbol AS token_symbol, t.name AS token_name, t.icon_url AS token_icon_url
        FROM (SELECT inscription_hash, asset FROM outputs WHERE state = 'unspent' AND inscription_hash IS NOT NULL) op
            INNER JOIN inscription_items i ON i.inscription_hash = op.inscription_hash
            INNER JOIN tokens t ON t.kernel_asset_id = op.asset
            LEFT JOIN inscription_collections ic ON i.collection_hash = ic.collection_hash
        """
        static let order = "i.updated_at DESC"
        static let selectWithInscriptionHash = "\(SQL.selector) WHERE op.inscription_hash = ?"
    }
    
    public static let shared = InscriptionDAO()
    
    public func inscriptionItem(with inscriptionHash: String) -> InscriptionItem? {
        db.select(with: SQL.selectWithInscriptionHash, arguments: [inscriptionHash])
    }
    
    public func allInscriptions() -> [InscriptionItem] {
        db.select(with: SQL.selector)
    }
    
    public func search(keyword: String, limit: Int?) -> [InscriptionItem] {
        var sql = """
        \(SQL.selector)
        \nWHERE ic.name LIKE :keyword'
        """
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        return db.select(with: sql, arguments: ["keyword": "%\(keyword)%"])
    }
    
    public func inscriptionExists(inscriptionHash: String) -> Bool {
        db.recordExists(in: Inscription.self, where: Inscription.column(of: .inscriptionHash) == inscriptionHash)
    }
    
    public func save(inscription: Inscription) {
        db.save(inscription)
    }
    
    public func saveAndFetch(inscription: Inscription) -> InscriptionItem? {
        try! db.writeAndReturnError { db in
            try inscription.save(db)
            return try InscriptionItem.fetchOne(db, sql: SQL.selectWithInscriptionHash, arguments: [inscription.inscriptionHash])
        }
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
