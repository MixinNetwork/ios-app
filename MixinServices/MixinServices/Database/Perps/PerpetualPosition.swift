import Foundation
import GRDB

public class PerpetualPosition: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case positionID = "position_id"
        case productID = "product_id"
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
        case botID = "bot_id"
        case walletID = "wallet_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public let positionID: String
    public let productID: String
    public let side: String
    public let quantity: String
    public let entryPrice: String
    public let margin: String
    public let leverage: Int
    public let state: String
    public let markPrice: String
    public let unrealizedPnL: String
    public let roe: String
    public let settleAssetID: String
    public let botID: String
    public let walletID: String
    public let createdAt: String
    public let updatedAt: String
    
    private init(
        positionID: String,
        productID: String,
        side: String,
        quantity: String,
        entryPrice: String,
        margin: String,
        leverage: Int,
        state: String,
        markPrice: String,
        unrealizedPnL: String,
        roe: String,
        settleAssetID: String,
        botID: String,
        walletID: String,
        createdAt: String,
        updatedAt: String
    ) {
        self.positionID = positionID
        self.productID = productID
        self.side = side
        self.quantity = quantity
        self.entryPrice = entryPrice
        self.margin = margin
        self.leverage = leverage
        self.state = state
        self.markPrice = markPrice
        self.unrealizedPnL = unrealizedPnL
        self.roe = roe
        self.settleAssetID = settleAssetID
        self.botID = botID
        self.walletID = walletID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
}

extension PerpetualPosition: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "positions"
    
}
