import Foundation
import GRDB

public struct SwapOrder {
    
    public enum State: String {
        case pending
        case success
        case failed
    }
    
    public enum OrderType: String {
        case swap
        case limit
    }
    
    public let orderID: String
    public let userID: String
    public let payAssetID: String
    public let receiveAssetID: String
    public let payAmount: String
    public let receiveAmount: String
    public let payTraceID: String
    public let receiveTraceID: String
    public let state: String
    public let createdAt: String
    public let orderType: String
    
}

extension SwapOrder: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case userID = "user_id"
        case payAssetID = "pay_asset_id"
        case receiveAssetID = "receive_asset_id"
        case payAmount = "pay_amount"
        case receiveAmount = "receive_amount"
        case payTraceID = "pay_trace_id"
        case receiveTraceID = "receive_trace_id"
        case state = "state"
        case createdAt = "created_at"
        case orderType = "order_type"
    }
    
}

extension SwapOrder: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "swap_orders"
    
}
