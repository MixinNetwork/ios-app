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
    }
    
}

extension DepositEntry: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "deposit_entries"
    
}

extension DepositEntry {
    
    private static let kernelPublicKey: Curve25519.Signing.PublicKey = {
        let data = Data(hexEncodedString: "8f94e89d03fa128a7081c5fe73c6814010c5ca74438411a42df87c6023dfa94d")!
        return try! Curve25519.Signing.PublicKey(rawRepresentation: data)
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
        return Self.kernelPublicKey.isValidSignature(signature, for: contentHash)
    }
    
}
