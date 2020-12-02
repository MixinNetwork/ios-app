import Foundation
import GRDB

struct Identity {
    
    let address: String
    let registrationId: Int?
    let publicKey: Data
    let privateKey: Data?
    let nextPreKeyId: Int64?
    let timestamp: TimeInterval
    
}

extension Identity: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: CodingKey {
        case address
        case registrationId
        case publicKey
        case privateKey
        case nextPreKeyId
        case timestamp
    }
    
}

extension Identity: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "identities"
    
}

extension Identity {
    
    func getIdentityKeyPair() -> KeyPair {
        return KeyPair(publicKey: publicKey, privateKey: privateKey!)
    }
    
}
