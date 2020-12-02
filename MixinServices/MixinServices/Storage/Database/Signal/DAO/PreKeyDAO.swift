import Foundation
import GRDB

internal class PreKeyDAO: SignalDAO {
    
    static let shared = PreKeyDAO()
    
    func getPreKey(preKeyId: Int) -> PreKey? {
        db.select(where: PreKey.column(of: .preKeyId) == preKeyId)
    }
    
    func deleteIdentity(preKeyId: Int) -> Bool {
        db.delete(PreKey.self, where: PreKey.column(of: .preKeyId) == preKeyId)
        return true
    }
    
}
