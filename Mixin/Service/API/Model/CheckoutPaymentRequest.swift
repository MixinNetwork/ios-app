import Foundation

struct CheckoutPaymentRequest {
    
    enum Payment {
        case token(String)
        case instrument(id: String, sessionID: String)
    }
    
    let assetID: String
    let payment: Payment
    let scheme: String
    let amount: Int
    let assetAmount: String
    let currency: String
    
    init(
        assetID: String,
        payment: Payment,
        scheme: String,
        amount: Int,
        assetAmount: String,
        currency: String
    ) {
        self.assetID = assetID
        self.payment = payment
        self.scheme = scheme
        self.amount = amount
        self.assetAmount = assetAmount
        self.currency = currency
    }
    
}

extension CheckoutPaymentRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case token
        case instrumentID = "instrument_id"
        case scheme
        case amount
        case assetAmount = "asset_amount"
        case currency
        case sessionID = "session_id"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(assetID, forKey: .assetID)
        switch payment {
        case let .token(token):
            try container.encode(token, forKey: .token)
        case let .instrument(instrumentID, sessionID):
            try container.encode(instrumentID, forKey: .instrumentID)
            try container.encode(sessionID, forKey: .sessionID)
        }
        try container.encode(scheme, forKey: .scheme)
        try container.encode(amount, forKey: .amount)
        try container.encode(assetAmount, forKey: .assetAmount)
        try container.encode(currency, forKey: .currency)
    }
    
}
