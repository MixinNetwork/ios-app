import Foundation
import GRDB

public final class InscriptionDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let assetId = "aid"
    }
    
    private enum SQL {
        
        static let selector = """
        SELECT i.type, i.inscription_hash, i.collection_hash, i.sequence, i.content_type,
            i.content_url, i.occupied_by, i.occupied_at, i.created_at, i.updated_at,
            ic.type AS collection_type, ic.supply AS collection_supply, ic.unit AS collection_unit,
            ic.symbol AS collection_symbol, ic.name AS collection_name, ic.icon_url AS collection_icon_url,
            ic.created_at AS collection_created_at, ic.updated_at AS collection_updated_at
        FROM inscription_item i
            LEFT JOIN inscription_collection ic ON i.collection_hash = ic.collection_hash
        """
        static let selectWithInscriptionHash = "\(SQL.selector) WHERE i.inscription_hash = ?"
        
    }
    
    public static let shared = InscriptionDAO()
    
    public func tokenItem(with inscriptionHash: String) -> InscriptionItem? {
        db.select(with: SQL.selectWithInscriptionHash, arguments: [inscriptionHash])
    }
    
    public func inscriptionExists(inscriptionHash: String) -> Bool {
        db.recordExists(in: Inscription.self, where: Inscription.column(of: .inscriptionHash) == inscriptionHash)
    }
    
    public func save(inscription: Inscription) {
        db.save(inscription)
    }
    
    public func save(collection: InscriptionCollection) {
        db.save(collection)
    }
}
