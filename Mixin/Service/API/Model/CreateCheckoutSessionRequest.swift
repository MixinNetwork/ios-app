import Foundation

struct CreateCheckoutSessionRequest {
    
    let assetID: String
    let instrumentID: String
    let scheme: String
    let amount: Int
    let currency: String
    
    init(
        assetID: String,
        instrumentID: String,
        scheme: String,
        amount: Int,
        currency: String
    ) {
        self.assetID = assetID
        self.instrumentID = instrumentID
        self.scheme = scheme
        self.amount = amount
        self.currency = currency
    }
    
}

extension CreateCheckoutSessionRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case instrumentID = "instrument_id"
        case scheme
        case amount
        case currency
    }
    
}
