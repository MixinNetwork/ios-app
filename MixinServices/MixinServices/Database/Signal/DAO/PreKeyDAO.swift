import Foundation
import GRDB

internal class PreKeyDAO: SignalDAO {
    
    static let shared = PreKeyDAO()
    
    func getPreKey(with id: Int) -> PreKey? {
        db.select(where: PreKey.column(of: .preKeyId) == id)
    }
    
    func savePreKey(_ preKey: PreKey) -> Bool {
        db.save(preKey)
    }
    
    func savePreKeys(_ preKeys: [PreKey]) -> Bool {
        db.save(preKeys)
    }
    
    func deletePreKey(with id: Int) -> Bool {
        db.delete(PreKey.self, where: PreKey.column(of: .preKeyId) == id)
        return true
    }
    
}
