import Foundation
import WCDBSwift

class IdentityDao: SignalDAO {

    static let shared = IdentityDao()

    func getLocalIdentity() -> Identity? {
        return SignalDatabase.shared.getCodable(condition: Identity.Properties.address == "-1")
    }

    func getCount() -> Int {
        return SignalDatabase.shared.getCount(on: Identity.Properties.id.count(), fromTable: Identity.tableName)
    }
}
