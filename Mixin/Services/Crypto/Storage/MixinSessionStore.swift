import Foundation

class MixinSessionStore: SessionStore {

    private let lock = NSLock()

    func loadSession(for address: SignalAddress) -> (session: Data, userRecord: Data?)? {
        guard let session = SessionDAO.shared.getSession(address: address.name, device: Int(address.deviceId)) else {
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

        let oldSession = SessionDAO.shared.getSession(address: address.name, device:  Int(address.deviceId))
        let newSession = Session(address: address.name, device: Int(address.deviceId), record: session, timestamp: Date().timeIntervalSince1970)
        if oldSession == nil {
            SessionDAO.shared.insertOrReplace(obj: newSession)
        } else if oldSession!.record != session {
            // TODO should update with session
            ParticipantSessionDAO.shared.updateStatusByUserId(userId: address.name)
            SessionDAO.shared.insertOrReplace(obj: newSession)
        }
        return true
    }

    func containsSession(for address: SignalAddress) -> Bool {
        return SessionDAO.shared.isExist(address: address.name, device: Int(address.deviceId))
    }

    func deleteSession(for address: SignalAddress) -> Bool? {
        return SessionDAO.shared.delete(address: address.name, device: Int(address.deviceId))
    }

    func deleteAllSessions(for name: String) -> Int? {
        return SessionDAO.shared.delete(address: name)
    }
}
