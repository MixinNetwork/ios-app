import Foundation
import MixinServices

struct EarnProduct: Codable {
    
    enum CodingKeys: String, CodingKey {
        case productionID = "production_id"
        case assetID = "asset_id"
        case chainID = "chain_id"
        case iconURL = "icon_url"
        case annualRates = "annual_rates"
        case account = "account"
    }
    
    struct Account: Codable {
        
        enum CodingKeys: String, CodingKey {
            case totalPrincipal = "total_principal"
            case totalEarnings = "total_earnings"
            case yesterdayEarnings = "yesterday_earnings"
            case redeemableEarnings = "redeemable_earnings"
        }
        
        let totalPrincipal: String
        let totalEarnings: String
        let yesterdayEarnings: String
        let redeemableEarnings: String
        
    }
    
    let productionID: String
    let assetID: String
    let chainID: String
    let iconURL: String
    let annualRates: [String]
    let account: Account
    
}
