import XCTest
@testable import MixinServices

class SignalTests: XCTestCase {
    
    override class func setUp() {
        print("Testing with URL: \(AppGroupContainer.signalDatabaseUrl)")
        let fileExists = FileManager.default.fileExists(atPath: AppGroupContainer.signalDatabaseUrl.path)
        if fileExists {
            assertionFailure("The test corrupts your existed app data. Test it with a fresh device.")
        }
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        SignalDatabase.reloadCurrent()
    }
    
    override func tearDownWithError() throws {
        SignalDatabase.closeCurrent()
        let filenames = try FileManager.default.contentsOfDirectory(atPath: AppGroupContainer.documentsUrl.path)
        for filename in filenames {
            let url = AppGroupContainer.documentsUrl.appendingPathComponent(filename)
            try FileManager.default.removeItem(at: url)
        }
    }
    
    func testMigration() throws {
        try SignalDatabase.current!.pool.read { (db) -> Void in
            XCTAssertTrue(try db.tableExists("identities"))
            XCTAssertTrue(try db.tableExists("prekeys"))
            XCTAssertTrue(try db.tableExists("ratchet_sender_keys"))
            XCTAssertTrue(try db.tableExists("sender_keys"))
            XCTAssertTrue(try db.tableExists("sessions"))
            XCTAssertTrue(try db.tableExists("signed_prekeys"))
        }
    }
    
    func testErase() throws {
        SignalDatabase.current.erase()
        try SignalDatabase.current!.pool.read { (db) -> Void in
            XCTAssertFalse(try db.tableExists("identities"))
            XCTAssertFalse(try db.tableExists("prekeys"))
            XCTAssertFalse(try db.tableExists("ratchet_sender_keys"))
            XCTAssertFalse(try db.tableExists("sender_keys"))
            XCTAssertFalse(try db.tableExists("sessions"))
            XCTAssertFalse(try db.tableExists("signed_prekeys"))
        }
    }
    
    func testIdentityDAO() {
        let dao = IdentityDAO.shared
        
        let pk1 = Data([0x01, 0x02, 0x03])
        let a1 = "-1"
        XCTAssertEqual(dao.getCount(), 0)
        XCTAssertTrue(dao.save(publicKey: pk1, for: a1))
        XCTAssertEqual(dao.getCount(), 1)
        
        let i1 = dao.getLocalIdentity()!
        XCTAssertEqual(pk1, i1.publicKey)
        XCTAssertEqual(a1, i1.address)
        
        let pk2 = Data([0x04, 0x05, 0x06])
        XCTAssertTrue(dao.save(publicKey: pk2, for: a1))
        let i2 = dao.getLocalIdentity()!
        XCTAssertEqual(pk2, i2.publicKey)
        
        XCTAssertEqual(dao.getCount(), 1)
        dao.deleteIdentity(address: a1)
        XCTAssertEqual(dao.getCount(), 0)
        
        dao.saveLocalIdentity()
        
        let identity = dao.getLocalIdentity()!
        XCTAssertEqual(identity.registrationId, Int(AppGroupUserDefaults.Signal.registrationId))
        XCTAssertEqual(identity.publicKey, AppGroupUserDefaults.Signal.publicKey)
        XCTAssertEqual(identity.privateKey, AppGroupUserDefaults.Signal.privateKey)
        XCTAssertNil(identity.nextPreKeyId)
    }
    
    func testPreKeyDAO() {
        let dao = PreKeyDAO.shared
        let keys = [
            PreKey(preKeyId: 0, record: Data([0x01, 0x02, 0x03])),
            PreKey(preKeyId: 1, record: Data([0x04, 0x05, 0x06])),
            PreKey(preKeyId: 2, record: Data([0x07, 0x08, 0x09])),
        ]
        
        XCTAssertTrue(dao.savePreKey(keys[0]))
        let loadedKey = dao.getPreKey(with: keys[0].preKeyId)!
        XCTAssertEqual(loadedKey.preKeyId, keys[0].preKeyId)
        XCTAssertEqual(loadedKey.record, keys[0].record)
        
        XCTAssertTrue(dao.deletePreKey(with: keys[0].preKeyId))
        XCTAssertNil(dao.getPreKey(with: keys[0].preKeyId))
        
        XCTAssertTrue(dao.savePreKeys(keys))
        for key in keys {
            let loaded = dao.getPreKey(with: key.preKeyId)!
            XCTAssertEqual(loaded.preKeyId, key.preKeyId)
            XCTAssertEqual(loaded.record, key.record)
        }
    }
    
    func testRatchetSenderKeyDAO() {
        let dao = RatchetSenderKeyDAO.shared
        let sessionId = UUID().uuidString.lowercased()
        let address = SignalAddress(name: UUID().uuidString.lowercased(),
                                    deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
        let key = RatchetSenderKey(groupId: UUID().uuidString.lowercased(),
                                   senderId: address.toString(),
                                   status: RatchetStatus.REQUESTING.rawValue)
        
        dao.saveRatchetSenderKey(key)
        let loadedKey = dao.getRatchetSenderKey(groupId: key.groupId, senderId: key.senderId)!
        XCTAssertEqual(loadedKey.groupId, key.groupId)
        XCTAssertEqual(loadedKey.senderId, key.senderId)
        XCTAssertEqual(loadedKey.status, key.status)
        
        dao.delete(groupId: key.groupId, senderId: key.senderId)
        XCTAssertNil(dao.getRatchetSenderKey(groupId: key.groupId, senderId: key.senderId))
        
        dao.saveRatchetSenderKey(key)
        let loadedStatus = dao.getRatchetSenderKeyStatus(groupId: key.groupId,
                                                            senderId: key.senderId,
                                                            sessionId: sessionId)
        XCTAssertEqual(loadedStatus, key.status)
        
        dao.deleteRatchetSenderKey(groupId: key.groupId,
                                   senderId: key.senderId)
        XCTAssertNil(dao.getRatchetSenderKey(groupId: key.groupId, senderId: key.senderId))
    }
    
    func testSenderKeyDAO() {
        let dao = SenderKeyDAO()
        
        let keys = [
            SenderKey(groupId: UUID().uuidString.lowercased(),
                      senderId: UUID().uuidString.lowercased(),
                      record: Data([0x01, 0x02, 0x03])),
            SenderKey(groupId: UUID().uuidString.lowercased(),
                      senderId: UUID().uuidString.lowercased(),
                      record: Data([0x04, 0x05, 0x06])),
            SenderKey(groupId: UUID().uuidString.lowercased(),
                      senderId: UUID().uuidString.lowercased(),
                      record: Data([0x07, 0x08, 0x09])),
        ]
        
        dao.db.save(keys)
        let loadedKey = dao.getSenderKey(groupId: keys[0].groupId,
                                         senderId: keys[0].senderId)!
        XCTAssertEqual(keys[0].groupId, loadedKey.groupId)
        XCTAssertEqual(keys[0].senderId, loadedKey.senderId)
        XCTAssertEqual(keys[0].record, loadedKey.record)
        
        XCTAssertTrue(dao.delete(groupId: keys[0].groupId, senderId: keys[0].senderId))
        let loadedKeys = dao.getAllSenderKeys()
        XCTAssertEqual(loadedKeys.count, 2)
        
        XCTAssertEqual(loadedKeys[0].groupId, keys[1].groupId)
        XCTAssertEqual(loadedKeys[0].senderId, keys[1].senderId)
        XCTAssertEqual(loadedKeys[0].record, keys[1].record)
        
        XCTAssertEqual(loadedKeys[1].groupId, keys[2].groupId)
        XCTAssertEqual(loadedKeys[1].senderId, keys[2].senderId)
        XCTAssertEqual(loadedKeys[1].record, keys[2].record)
    }
    
    func testSessionDAO() {
        let dao = SessionDAO.shared
        
        let duplicatedAddress = UUID().uuidString.lowercased()
        let sessions = [
            Session(address: duplicatedAddress,
                    device: 1,
                    record: Data([0x01, 0x02, 0x03]),
                    timestamp: Date().timeIntervalSince1970),
            Session(address: duplicatedAddress,
                    device: 2,
                    record: Data([0x04, 0x05, 0x06]),
                    timestamp: Date().timeIntervalSince1970),
            Session(address: UUID().uuidString.lowercased(),
                    device: 3,
                    record: Data([0x07, 0x08, 0x09]),
                    timestamp: Date().timeIntervalSince1970),
            Session(address: UUID().uuidString.lowercased(),
                    device: 4,
                    record: Data([0x10, 0x11, 0x12]),
                    timestamp: Date().timeIntervalSince1970),
        ]
        
        func areSessionsEqual(_ one: Session, _ another: Session) -> Bool {
            one.address == another.address
                && one.device == another.device
                && one.record == another.record
                && one.timestamp == another.timestamp
        }
        
        func isSessionGroupEqual(_ one: [Session], _ another: [Session]) -> Bool {
            guard one.count == another.count else {
                return false
            }
            for s1 in one {
                let contains = another.contains(where: { (s2) -> Bool in
                    areSessionsEqual(s1, s2)
                })
                if !contains {
                    return false
                }
            }
            return true
        }
        
        dao.db.save(sessions)
        
        for session in sessions {
            XCTAssertTrue(dao.sessionExists(address: session.address, device: session.device))
        }
        XCTAssertEqual(sessions.count, dao.getCount())
        
        let loadedSession = dao.getSession(address: sessions[0].address,
                                           device: sessions[0].device)!
        XCTAssertTrue(areSessionsEqual(loadedSession, sessions[0]))
        
        let sg1 = sessions.filter({ $0.address == duplicatedAddress })
        let sg2 = dao.getSessions(address: duplicatedAddress)
        XCTAssertTrue(isSessionGroupEqual(sg1, sg2))
        
        let s1 = dao.getSubDevices(address: duplicatedAddress)
            .sorted(by: <)
        let s2 = sessions.filter({ $0.address == duplicatedAddress })
            .map(\.device).map(Int32.init).filter({ $0 != 1 })
            .sorted(by: <)
        XCTAssertEqual(s1, s2)
        
        let sa1 = sessions.filter({ $0.device == 1 })
        let sa2 = dao.getSessionAddress()
        XCTAssertTrue(isSessionGroupEqual(sa1, sa2))
        
        dao.delete(address: duplicatedAddress)
        XCTAssertEqual(sessions.filter({ $0.address != duplicatedAddress }).count,
                       dao.getCount())
        
        XCTAssertTrue(dao.delete(address: sessions[3].address, device: sessions[3].device))
        XCTAssertEqual(dao.getCount(), 1)
        
        let oldSession = sessions[2]
        let newRecord = Data([0x13, 0x14, 0x15])
        let newTimestamp = Date().timeIntervalSince1970
        let assignments = [
            Session.column(of: .record).set(to: newRecord),
            Session.column(of: .timestamp).set(to: newTimestamp)
        ]
        dao.updateSession(with: oldSession.address, device: oldSession.device, assignments: assignments)
        let newSession = dao.getSession(address: oldSession.address, device: oldSession.device)!
        XCTAssertEqual(newSession.record, newRecord)
        XCTAssertEqual(newSession.timestamp, newTimestamp)
    }
    
    func testSignedPreKeyDAO() {
        let dao = SignedPreKeyDAO.shared
        let keys = [
            SignedPreKey(preKeyId: 0,
                         record: Data([0x01, 0x02, 0x03]),
                         timestamp: Date().timeIntervalSince1970),
            SignedPreKey(preKeyId: 1,
                         record: Data([0x04, 0x05, 0x06]),
                         timestamp: Date().timeIntervalSince1970),
            SignedPreKey(preKeyId: 2,
                         record: Data([0x07, 0x08, 0x09]),
                         timestamp: Date().timeIntervalSince1970),
        ]
        
        func areKeysEqual(_ one: SignedPreKey, _ another: SignedPreKey) -> Bool {
            one.preKeyId == another.preKeyId
                && one.record == another.record
                && one.timestamp == another.timestamp
        }
        
        func isKeyGroupEqual(_ one: [SignedPreKey], _ another: [SignedPreKey]) -> Bool {
            guard one.count == another.count else {
                return false
            }
            for s1 in one {
                let contains = another.contains(where: { (s2) -> Bool in
                    areKeysEqual(s1, s2)
                })
                if !contains {
                    return false
                }
            }
            return true
        }
        
        dao.db.save(keys)
        
        let k1 = keys[0]
        let k2 = dao.getSignedPreKey(signedPreKeyId: k1.preKeyId)!
        XCTAssertTrue(areKeysEqual(k1, k2))
        
        let kg1 = keys
        let kg2 = dao.getSignedPreKeyList()
        XCTAssertTrue(isKeyGroupEqual(kg1, kg2))
        
        XCTAssertTrue(dao.delete(signedPreKeyId: keys[0].preKeyId))
        let kg3 = Array(keys.dropFirst())
        let kg4 = dao.getSignedPreKeyList()
        XCTAssertTrue(isKeyGroupEqual(kg3, kg4))
    }
    
}
