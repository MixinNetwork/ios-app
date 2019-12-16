import Foundation
import WCDBSwift

class PreKeyDAO: SignalDAO {

    static let shared = PreKeyDAO()

    func getPreKey(preKeyId: Int) -> PreKey? {
        return SignalDatabase.shared.getCodable(condition: PreKey.Properties.preKeyId == preKeyId)
    }

    func deleteIdentity(preKeyId: Int) -> Bool {
        SignalDatabase.shared.delete(table: PreKey.tableName, condition: PreKey.Properties.preKeyId == preKeyId)
        return true
    }
}
