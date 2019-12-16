import Foundation
import WCDBSwift

class SessionDAO: SignalDAO {
    static let shared = SessionDAO()

    func getSession(address: String, device: Int) -> Session? {
        return SignalDatabase.shared.getCodable(condition: Session.Properties.address == address && Session.Properties.device == device)
    }

    func delete(address: String, device: Int) -> Bool {
        SignalDatabase.shared.delete(table: Session.tableName, condition: Session.Properties.address == address && Session.Properties.device == device)
        return true
    }

    @discardableResult
    func delete(address: String) -> Int {
        return SignalDatabase.shared.delete(table: Session.tableName, condition: Session.Properties.address == address)
    }

    func isExist(address: String, device: Int) -> Bool {
        return SignalDatabase.shared.isExist(type: Session.self, condition: Session.Properties.address == address && Session.Properties.device == device)
    }

    func getSubDevices(address: String) -> [Int32] {
        return SignalDatabase.shared.getInt32Values(column: Session.Properties.device.asColumnResult(), tableName: Session.tableName, condition: Session.Properties.address == address && Session.Properties.device != 1)
    }

    func getSessions(address: String) -> [Session] {
        return SignalDatabase.shared.getCodables(condition: Session.Properties.address == address)
    }

    func getCount() -> Int {
        return SignalDatabase.shared.getCount(on: Session.Properties.id.count(), fromTable: Session.tableName)
    }

    func syncGetSessionAddress() -> [Session] {
        return SignalDatabase.shared.getCodables(condition: Session.Properties.device == 1)
    }

}
