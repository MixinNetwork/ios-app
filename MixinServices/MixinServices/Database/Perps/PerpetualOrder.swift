import Foundation
import GRDB

public class PerpetualOrder: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case positionID = "position_id"
        case marketID = "market_id"
        case side = "side"
        case orderType = "order_type"
        case payAmount = "pay_amount"
        case status = "status"
        case leverage = "leverage"
        case quantity = "quantity"
        case entryPrice = "entry_price"
        case closePrice = "close_price"
        case realizedPnL = "realized_pnl"
        case roe = "roe"
        case closeReason = "close_reason"
        case triggerPrice = "trigger_price"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public enum OrderType: String {
        case open
        case increasePosition = "increase_position"
        case close
    }
    
    public enum Status: String {
        case processing
        case filled
        case rejected
        case closed
    }
    
    public let orderID: String
    public let positionID: String
    public let marketID: String
    public let side: String
    public let orderType: UnknownableEnum<OrderType>
    public let payAmount: String
    public let status: UnknownableEnum<Status>
    public let leverage: Int
    public let quantity: String
    public let entryPrice: String
    public let closePrice: String
    public let realizedPnL: String
    public let roe: String
    public let closeReason: String?
    public let triggerPrice: String?
    public let createdAt: String
    public let updatedAt: String
    
}

extension PerpetualOrder: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "perps_orders"
    
}
