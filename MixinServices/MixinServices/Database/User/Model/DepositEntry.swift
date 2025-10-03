import Foundation
import CryptoKit
import GRDB

public struct DepositEntry {
    
    public let id: String
    public let chainID: String
    public let isPrimary: Bool
    public let members: [String]
    public let destination: String
    public let tag: String?
    public let signature: String
    public let threshold: Int
    public let minimum: String
    public let maximum: String
    
}

extension DepositEntry: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case id = "entry_id"
        case chainID = "chain_id"
        case isPrimary = "is_primary"
        case members
        case destination
        case tag
        case signature
        case threshold
        case minimum
        case maximum
    }
    
}

extension DepositEntry: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "deposit_entries"
    
}

extension DepositEntry {
    
    private static let kernelPublicKeys: [Curve25519.Signing.PublicKey] = {
        let keys = [
            "8f94e89d03fa128a7081c5fe73c6814010c5ca74438411a42df87c6023dfa94d",
            "2dc073588908a02284197ad78fc863e83c760dabcd5d9a508e09a799ebc1ecb8",
        ]
        return keys.map { key in
            let data = Data(hexEncodedString: key)!
            return try! Curve25519.Signing.PublicKey(rawRepresentation: data)
        }
    }()
    
    public var isSignatureValid: Bool {
        guard let signature = Data(hexEncodedString: signature) else {
            return false
        }
        let content: String
        if let tag, !tag.isEmpty {
            content = destination + ":" + tag
        } else {
            content = destination
        }
        guard let content = content.data(using: .utf8), let contentHash = SHA3_256.hash(data: content) else {
            return false
        }
        return Self.kernelPublicKeys.contains { key in
            key.isValidSignature(signature, for: contentHash)
        }
    }
    
}
