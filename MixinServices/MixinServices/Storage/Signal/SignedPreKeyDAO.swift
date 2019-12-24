import Foundation
import WCDBSwift

internal class SignedPreKeyDAO: SignalDAO {

    static let shared = SignedPreKeyDAO()

    func getSignedPreKey(signedPreKeyId: Int) -> SignedPreKey? {
        return SignalDatabase.shared.getCodable(condition: SignedPreKey.Properties.preKeyId == signedPreKeyId)
    }

    func getSignedPreKeyList() -> [SignedPreKey] {
        return SignalDatabase.shared.getCodables()
    }

    func delete(signedPreKeyId: Int) -> Bool {
        SignalDatabase.shared.delete(table: SignedPreKey.tableName, condition: SignedPreKey.Properties.preKeyId == signedPreKeyId)
        return true
    }

}
