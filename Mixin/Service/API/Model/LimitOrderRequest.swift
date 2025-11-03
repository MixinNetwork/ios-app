import Foundation
import MixinServices

struct LimitOrderRequest {
    
    let assetID: String
    let amount: String
    let receiveAssetID: String
    let expectedReceiveAmount: String
    let expireAt: String
    
    init(
        assetID: String,
        amount: Decimal,
        receiveAssetID: String,
        expectedReceiveAmount: Decimal,
        expireAt: Date,
    ) {
        self.assetID = assetID
        self.amount = TokenAmountFormatter.string(from: amount)
        self.receiveAssetID = receiveAssetID
        self.expectedReceiveAmount = TokenAmountFormatter.string(from: expectedReceiveAmount)
        self.expireAt = DateFormatter.iso8601Full.string(from: expireAt)
    }
    
}

extension LimitOrderRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case amount
        case receiveAssetID = "receive_asset_id"
        case expectedReceiveAmount = "expected_receive_amount"
        case expireAt = "expire_at"
    }
    
}
