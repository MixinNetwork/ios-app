import Foundation

class MixinSessionStore: SessionStore {
    
    private let lock = NSLock()
    
    func loadSession(for address: SignalAddress) -> (session: Data, userRecord: Data?)? {
        guard let session = SessionDAO.shared.getSession(address: address.name, device: address.deviceId) else {
            return nil
        }
        return (session.record, nil)
    }
    
    func subDeviceSessions(for name: String) -> [Int32]? {
        return SessionDAO.shared.getSubDevices(address: name)
    }
    
    func store(session: Data, for address: SignalAddress, userRecord: Data?) -> Bool {
        objc_sync_enter(lock)
        defer {
            objc_sync_exit(lock)
        }
        
        let oldSession = SessionDAO.shared.getSession(address: address.name, device: address.deviceId)
        if oldSession == nil {
            let newSession = Session(address: address.name,
                                     device: address.deviceId,
                                     record: session,
                                     timestamp: Date().timeIntervalSince1970)
            SignalDatabase.current.save(newSession)
        } else if oldSession!.record != session {
            let assignments = [
                Session.column(of: .record).set(to: session),
                Session.column(of: .timestamp).set(to: Date().timeIntervalSince1970)
            ]
            SessionDAO.shared.updateSession(with: address.name,
                                            device: address.deviceId,
                                            assignments: assignments)
        }
        return true
    }
    
    func containsSession(for address: SignalAddress) -> Bool {
        return SessionDAO.shared.sessionExists(address: address.name, device: address.deviceId)
    }
    
    func deleteSession(for address: SignalAddress) -> Bool? {
        return SessionDAO.shared.delete(address: address.name, device: address.deviceId)
    }
    
    func deleteAllSessions(for name: String) -> Int? {
        return SessionDAO.shared.delete(address: name)
    }
    
}
