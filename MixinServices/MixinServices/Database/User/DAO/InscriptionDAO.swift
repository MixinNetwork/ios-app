import Foundation
import GRDB

public final class InscriptionDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let assetId = "aid"
    }
    
    private enum SQL {
        
        static let selector = """
        SELECT i.*, ic.name AS collection_name, ic.icon_url AS collection_icon_url
        FROM inscription_item i
            LEFT JOIN inscription_collection ic ON i.collection_hash = ic.collection_hash
        """
        static let order = "i.updated_at DESC"
        static let selectWithInscriptionHash = "\(SQL.selector) WHERE i.inscription_hash = ?"
        static let selectAll = "\(SQL.selector) WHERE i.inscription_hash IN (SELECT inscription_hash FROM outputs WHERE state = 'unspent' AND IFNULL(inscription_hash,'') <> '')"
    }
    
    public static let shared = InscriptionDAO()
    
    public func tokenItem(with inscriptionHash: String) -> InscriptionItem? {
        db.select(with: SQL.selectWithInscriptionHash, arguments: [inscriptionHash])
    }
    
    public func allInscriptions() -> [InscriptionItem] {
        db.select(with: SQL.selectAll)
    }
    
    public func inscriptionExists(inscriptionHash: String) -> Bool {
        db.recordExists(in: Inscription.self, where: Inscription.column(of: .inscriptionHash) == inscriptionHash)
    }
    
    public func collectionExists(collectionHash: String) -> Bool {
        db.recordExists(in: InscriptionCollection.self, where: Inscription.column(of: .collectionHash) == collectionHash)
    }
    
    public func save(inscription: Inscription) {
        db.save(inscription)
    }
    
    public func save(collection: InscriptionCollection) {
        db.save(collection)
    }
}
