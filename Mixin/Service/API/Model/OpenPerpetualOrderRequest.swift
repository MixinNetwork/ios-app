import Foundation

struct OpenPerpetualOrderRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case marketID = "market_id"
        case side = "side"
        case amount = "amount"
        case leverage = "leverage"
        case walletID = "wallet_id"
        case destination = "destination"
    }
    
    let assetID: String
    let marketID: String
    let side: PerpetualOrderSide
    let amount: String
    let leverage: Int
    let walletID: String
    let destination: String?
    
}
