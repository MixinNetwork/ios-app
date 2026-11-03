import Foundation

struct OpenPerpetualOrderRequest: Encodable, Hashable {
    
    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case assetID = "asset_id"
        case marketID = "market_id"
        case side = "side"
        case amount = "amount"
        case leverage = "leverage"
        case walletID = "wallet_id"
        case destination = "destination"
        case takeProfitPrice = "take_profit_price"
        case stopLossPrice = "stop_loss_price"
        case leaderPositionID = "leader_position_id"
    }
    
    let orderID: String?
    let assetID: String
    let marketID: String
    let side: PerpetualOrderSide
    let amount: String
    let leverage: Int
    let walletID: String
    let destination: String?
    let takeProfitPrice: String?
    let stopLossPrice: String?
    let leaderPositionID: String?
    
}
