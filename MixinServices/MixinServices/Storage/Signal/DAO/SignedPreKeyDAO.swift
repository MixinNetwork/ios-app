import Foundation
import GRDB

internal class SignedPreKeyDAO: SignalDAO {
    
    static let shared = SignedPreKeyDAO()
    
    func getSignedPreKey(signedPreKeyId: Int) -> SignedPreKey? {
        db.select(where: SignedPreKey.column(of: .preKeyId) == signedPreKeyId)
    }
    
    func getSignedPreKeyList() -> [SignedPreKey] {
        db.selectAll()
    }
    
    func delete(signedPreKeyId: Int) -> Bool {
        db.delete(SignedPreKey.self, where: SignedPreKey.column(of: .preKeyId) == signedPreKeyId)
        return true
    }
    
}
