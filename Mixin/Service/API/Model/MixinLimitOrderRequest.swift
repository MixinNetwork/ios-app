import Foundation
import MixinServices

struct MixinLimitOrderRequest {
    
    let walletID: String
    let assetID: String
    let amount: String
    let receiveAssetID: String
    let expectedReceiveAmount: String
    let expireAt: String
    
    init(
        walletID: String,
        assetID: String,
        amount: Decimal,
        receiveAssetID: String,
        expectedReceiveAmount: Decimal,
        expireAt: Date,
    ) {
        self.walletID = walletID
        self.assetID = assetID
        self.amount = TokenAmountFormatter.string(from: amount)
        self.receiveAssetID = receiveAssetID
        self.expectedReceiveAmount = TokenAmountFormatter.string(from: expectedReceiveAmount)
        self.expireAt = DateFormatter.iso8601Full.string(from: expireAt)
    }
    
}

extension MixinLimitOrderRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case assetID = "asset_id"
        case amount
        case receiveAssetID = "receive_asset_id"
        case expectedReceiveAmount = "expected_receive_amount"
        case expireAt = "expired_at"
    }
    
}
