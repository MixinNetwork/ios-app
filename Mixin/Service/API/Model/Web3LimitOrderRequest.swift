import Foundation
import MixinServices

struct Web3LimitOrderRequest {
    
    let walletID: String
    let assetID: String
    let amount: String
    let assetDestination: String
    let receiveAssetID: String
    let expectedReceiveAmount: String
    let receiveAssetDestination: String
    let expireAt: String
    
    init(
        walletID: String,
        assetID: String,
        amount: Decimal,
        assetDestination: String,
        receiveAssetID: String,
        expectedReceiveAmount: Decimal,
        receiveAssetDestination: String,
        expireAt: Date,
    ) {
        self.walletID = walletID
        self.assetID = assetID
        self.amount = TokenAmountFormatter.string(from: amount)
        self.assetDestination = assetDestination
        self.receiveAssetID = receiveAssetID
        self.expectedReceiveAmount = TokenAmountFormatter.string(from: expectedReceiveAmount)
        self.receiveAssetDestination = receiveAssetDestination
        self.expireAt = DateFormatter.iso8601Full.string(from: expireAt)
    }
    
}

extension Web3LimitOrderRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case assetID = "asset_id"
        case amount
        case assetDestination = "asset_destination"
        case receiveAssetID = "receive_asset_id"
        case expectedReceiveAmount = "expected_receive_amount"
        case receiveAssetDestination = "receive_asset_destination"
        case expireAt = "expired_at"
    }
    
}
