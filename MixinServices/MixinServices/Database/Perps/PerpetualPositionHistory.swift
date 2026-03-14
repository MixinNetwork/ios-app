import Foundation
import GRDB

public class PerpetualPositionHistory: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case historyID = "history_id"
        case positionID = "position_id"
        case marketID = "market_id"
        case side = "side"
        case quantity = "quantity"
        case entryPrice = "entry_price"
        case closePrice = "close_price"
        case realizedPnL = "realized_pnl"
        case leverage = "leverage"
        case marginMethod = "margin_method"
        case openAt = "open_at"
        case closedAt = "closed_at"
    }
    
    public let historyID: String
    public let positionID: String
    public let marketID: String
    public let side: String
    public let quantity: String
    public let entryPrice: String
    public let closePrice: String
    public let realizedPnL: String
    public let leverage: Int
    public let marginMethod: String
    public let openAt: String
    public let closedAt: String
    
}

extension PerpetualPositionHistory: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "position_histories"
    
}
