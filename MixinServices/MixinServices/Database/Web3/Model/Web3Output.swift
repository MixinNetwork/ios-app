import Foundation
import GRDB

public struct Web3Output {
    
    public enum Status: String, SQLExpressible {
        case pending
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
    
    public let decimalAmount: Decimal
    
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
        self.decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let amount = try container.decode(String.self, forKey: .amount)
        self.id = try container.decode(String.self, forKey: .id)
        self.assetID = try container.decode(String.self, forKey: .assetID)
        self.transactionHash = try container.decode(String.self, forKey: .transactionHash)
        self.outputIndex = try container.decode(Int.self, forKey: .outputIndex)
        self.amount = amount
        self.address = try container.decode(String.self, forKey: .address)
        self.pubkeyHex = try container.decode(String.self, forKey: .pubkeyHex)
        self.pubkeyType = try container.decode(String.self, forKey: .pubkeyType)
        self.status = try container.decode(UnknownableEnum<Status>.self, forKey: .status)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    }
    
}

extension Web3Output: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "outputs"
    
}

extension Web3Output {
    
    public static func bitcoinOutputID<Interger: FixedWidthInteger>(txid: String, vout: Interger) -> String {
        "\(txid):\(vout)".uuidDigest()
    }
    
}

extension Web3Output: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "<Web3Output id: \(id), hash: \(transactionHash), index: \(outputIndex)>"
    }
    
}
