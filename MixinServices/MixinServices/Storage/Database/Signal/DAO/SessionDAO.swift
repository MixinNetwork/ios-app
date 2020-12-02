import Foundation
import GRDB

public class SessionDAO: SignalDAO {
    
    public static let shared = SessionDAO()
    
    func getSession(address: String, device: Int) -> Session? {
        db.select(where: Session.column(of: .address) == address && Session.column(of: .device) == device)
    }
    
    func delete(address: String, device: Int) -> Bool {
        db.delete(Session.self, where: Session.column(of: .address) == address && Session.column(of: .device) == device)
        return true
    }
    
    @discardableResult
    func delete(address: String) -> Int {
        db.delete(Session.self, where: Session.column(of: .address) == address)
    }
    
    func isExist(address: String, device: Int) -> Bool {
        db.recordExists(in: Session.self, where: Session.column(of: .address) == address && Session.column(of: .device) == device)
    }
    
    func getSubDevices(address: String) -> [Int32] {
        db.select(column: Session.column(of: .device),
                  from: Session.self,
                  where: Session.column(of: .address) == address && Session.column(of: .device) != 1)
    }
    
    func getSessions(address: String) -> [Session] {
        db.select(where: Session.column(of: .address) == address)
    }
    
    func getCount() -> Int {
        db.count(in: Session.self)
    }
    
    public func syncGetSessionAddress() -> [Session] {
        db.select(where: Session.column(of: .device) == 1)
    }
    
}
