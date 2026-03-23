import Foundation
import GRDB

public class PerpetualPosition: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum State: String {
        case opening
    }
    
    public enum CodingKeys: String, CodingKey {
        case positionID = "position_id"
        case marketID = "market_id"
        case side = "side"
        case quantity = "quantity"
        case entryPrice = "entry_price"
        case margin = "margin"
        case leverage = "leverage"
        case state = "state"
        case markPrice = "mark_price"
        case unrealizedPnL = "unrealized_pnl"
        case roe = "roe"
        case settleAssetID = "settle_asset_id"
        case openPayAmount = "open_pay_amount"
        case openPayAssetID = "open_pay_asset_id"
        case botID = "bot_id"
        case walletID = "wallet_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public let positionID: String
    public let marketID: String
    public let side: String
    public let quantity: String
    public let entryPrice: String
    public let margin: String
    public let leverage: Int
    public let state: UnknownableEnum<State>
    public let markPrice: String
    public let unrealizedPnL: String
    public let roe: String
    public let settleAssetID: String
    public let openPayAmount: String
    public let openPayAssetID: String
    public let botID: String
    public let walletID: String
    public let createdAt: String
    public let updatedAt: String
    
}

extension PerpetualPosition: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "positions"
    
}
