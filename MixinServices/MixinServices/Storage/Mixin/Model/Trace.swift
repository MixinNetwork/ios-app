import Foundation
import WCDBSwift

public struct Trace: BaseCodable {

    public static let tableName: String = "traces"

    public let traceId: String
    public let assetId: String
    public let amount: String
    public let opponentId: String?
    public let destination: String?
    public let tag: String?
    public let snapshotId: String?
    public let createdAt: String

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = Trace
        case traceId = "trace_id"
        case assetId = "asset_id"
        case amount
        case opponentId = "opponent_id"
        case destination
        case tag
        case snapshotId = "snapshot_id"
        case createdAt = "created_at"

        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                traceId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }

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
