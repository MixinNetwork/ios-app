import Foundation
import GRDB

public struct Web3Output {
    
    public enum Status: String {
        case unspent
        case signed
    }
    
    public let id: String
    public let assetID: String
    public let transactionHash: String
    public let outputIndex: Int
    public let amount: String
    public let address: String
    public let pubkeyHex: String
    public let pubkeyType: String
    public let status: UnknownableEnum<Status>
    public let createdAt: String
    public let updatedAt: String
    
    public init(
        id: String, assetID: String, transactionHash: String,
        outputIndex: Int, amount: String, address: String,
        pubkeyHex: String, pubkeyType: String,
        status: Web3Output.Status, createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.assetID = assetID
        self.transactionHash = transactionHash
        self.outputIndex = outputIndex
        self.amount = amount
        self.address = address
        self.pubkeyHex = pubkeyHex
        self.pubkeyType = pubkeyType
        self.status = .known(status)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
}

extension Web3Output: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case id = "output_id"
        case assetID = "asset_id"
        case transactionHash = "transaction_hash"
        case outputIndex = "output_index"
        case amount = "amount"
        case address = "address"
        case pubkeyHex = "pubkey_hex"
        case pubkeyType = "pubkey_type"
        case status = "status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
}

extension Web3Output: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "outputs"
    
}

extension Web3Output {
    
    public static func bitcoinOutputID<Interger: FixedWidthInteger>(txid: String, vout: Interger) -> String {
        "\(txid):\(1)".uuidDigest()
    }
    
}

extension Web3Output: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "<Web3Output id: \(id), hash: \(transactionHash), index: \(outputIndex)>"
    }
    
}
