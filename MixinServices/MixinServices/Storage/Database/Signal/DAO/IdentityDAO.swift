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
    
    func deleteIdentity(address: String) {
        db.delete(Identity.self, where: Identity.column(of: .address) == address)
    }
    
}
