import Foundation
import GRDB

public class SessionDAO: SignalDAO {
    
    public static let shared = SessionDAO()
    
    func sessionExists(address: String, device: Int32) -> Bool {
        db.recordExists(in: Session.self, where: Session.column(of: .address) == address && Session.column(of: .device) == device)
    }
    
    func getCount() -> Int {
        db.count(in: Session.self)
    }
    
}

extension SessionDAO {
    
    func getSession(address: String, device: Int32) -> Session? {
        db.select(where: Session.column(of: .address) == address && Session.column(of: .device) == device)
    }
    
    func getSessions(address: String) -> [Session] {
        db.select(where: Session.column(of: .address) == address)
    }
    
    func getSubDevices(address: String) -> [Int32] {
        db.select(column: Session.column(of: .device),
                  from: Session.self,
                  where: Session.column(of: .address) == address && Session.column(of: .device) != 1)
    }
    
    public func getSessionAddress() -> [Session] {
        db.select(where: Session.column(of: .device) == 1)
    }
    
}

extension SessionDAO {
    
    func updateSession(with address: String, device: Int32, assignments: [ColumnAssignment]) {
        db.update(Session.self,
                  assignments: assignments,
                  where: Session.column(of: .address) == address && Session.column(of: .device) == device)
    }
    
    @discardableResult
    func delete(address: String) -> Int {
        db.delete(Session.self, where: Session.column(of: .address) == address)
    }
    
    func delete(address: String, device: Int32) -> Bool {
        db.delete(Session.self, where: Session.column(of: .address) == address && Session.column(of: .device) == device)
        return true
    }
    
}
