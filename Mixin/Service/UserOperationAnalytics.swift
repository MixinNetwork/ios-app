import Foundation

enum UserOperationAnalytics {
    
    enum TradeSource: String {
        case walletHome         = "wallet_home"
        case tokenList          = "token_list"
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
    
    static var tradeSource: TradeSource?
    
}

extension UserOperationAnalytics {
    
    enum AddMobileNumberSource: String {
        case recoveryKitGuide   = "recovery_kit_guide"
        case buyGuide           = "buy_guide"
        case settings           = "settings"
    }
    
    static var addMobileNumberSource: AddMobileNumberSource?
    
}
