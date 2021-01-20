import Foundation
import GRDB

public struct Trace {
    
    public let traceId: String
    public let assetId: String
    public let amount: String
    public let opponentId: String?
    public let destination: String?
    public let tag: String?
    public let snapshotId: String?
    public let createdAt: String
    
    public init(traceId: String, assetId: String, amount: String, opponentId: String?, destination: String?, tag: String?, createdAt: String = Date().toUTCString()) {
        self.traceId = traceId
        self.assetId = assetId
        self.amount = amount
        self.opponentId = opponentId
        self.destination = destination
        self.tag = tag
        self.snapshotId = nil
        self.createdAt = createdAt
    }
    
}

extension Trace: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case assetId = "asset_id"
        case amount
        case opponentId = "opponent_id"
        case destination
        case tag
        case snapshotId = "snapshot_id"
        case createdAt = "created_at"
    }
    
}

extension Trace: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "traces"
    
}
