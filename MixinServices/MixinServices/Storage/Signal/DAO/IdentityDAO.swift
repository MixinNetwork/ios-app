import Foundation
import GRDB

public class IdentityDAO: SignalDAO {
    
    public static let shared = IdentityDAO()
    
    public func saveLocalIdentity() {
        let registrationId = Int(AppGroupUserDefaults.Signal.registrationId)
        let publicKey = AppGroupUserDefaults.Signal.publicKey
        let privateKey = AppGroupUserDefaults.Signal.privateKey
        let identity = Identity(address: "-1", registrationId: registrationId, publicKey: publicKey, privateKey: privateKey, nextPreKeyId: nil, timestamp: Date().timeIntervalSince1970)
        db.save(identity)
    }
    
    func getLocalIdentity() -> Identity? {
        db.select(where: Identity.column(of: .address) == "-1")
    }
    
    func getCount() -> Int {
        db.count(in: Identity.self)
    }
    
    func save(publicKey: Data, for address: String) -> Bool {
        db.write { (db) in
            let condition = Identity.column(of: .address) == address
            let timestamp = Date().timeIntervalSince1970
            let maybeRowID: Int? = try Identity.select(Column.rowID).filter(condition).fetchOne(db)
            let addressExists = maybeRowID != nil
            if addressExists {
                let assignments = [
                    Identity.column(of: .publicKey).set(to: publicKey),
                    Identity.column(of: .timestamp).set(to: timestamp),
                ]
                try Identity.filter(condition).updateAll(db, assignments)
            } else {
                let identity = Identity(address: address,
                                        registrationId: nil,
                                        publicKey: publicKey,
                                        privateKey: nil,
                                        nextPreKeyId: nil,
                                        timestamp: timestamp)
                try identity.insert(db)
            }
        }
    }
    
    func deleteIdentity(address: String) {
        db.delete(Identity.self, where: Identity.column(of: .address) == address)
    }
    
}
