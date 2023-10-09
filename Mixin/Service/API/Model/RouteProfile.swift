import Foundation

struct RouteProfile {
    
    enum Payment: String {
        case applePay = "applepay"
        case card
    }
    
    let kycState: KYCState
    let assetIDs: [String]
    let currencies: [String]
    let supportPayments: Set<Payment>
    
}

extension RouteProfile: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case kycState = "kyc_state"
        case assetIDs = "asset_ids"
        case currencies
        case supportPayments = "support_payments"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payments = try container.decode([String].self, forKey: .supportPayments)
        
        self.kycState = try container.decode(KYCState.self, forKey: .kycState)
        self.assetIDs = try container.decode([String].self, forKey: .assetIDs)
        self.currencies = try container.decode([String].self, forKey: .currencies)
        self.supportPayments = Set(payments.compactMap(Payment.init))
    }
    
}
