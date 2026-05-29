import Foundation

enum UserOperationAnalytics {
    
    enum Source: String {
        case walletHome         = "wallet_home"
        case moreExplore        = "more_explore"
        case appCard            = "app_card"
        case marketDetail       = "market_detail"
        case tradeDetail        = "trade_detail"
        case assetDetail        = "asset_detail"
        case perpsMarginInput   = "perps_margin_input"
        case transfer           = "transfer"
        case withdraw           = "withdraw"
        case scheme             = "scheme"
    }
    
    static var tradeSource: Source?
    
}
