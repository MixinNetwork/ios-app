import Foundation

struct TradeURL {
    
    struct LeaderPosition {
        let marketID: String
        let side: PerpetualOrderSide
        let leverage: Int?
        let margin: Decimal?
        let id: String?
    }
    
    enum TradingType {
        case perpsMarket(id: String)
        case perpsAction(LeaderPosition)
        case trade(trading: TradeViewController.Trading?, input: String?, output: String?)
    }
    
    let type: TradingType
    let referral: String?
    
    init?(queryItems: [URLQueryItem]?) {
        let items = queryItems?.reduce(into: [:]) { result, item in
            result[item.name] = item.value
        } ?? [:]
        
        let type = items["type"]
        let input = items["input"]
        let output = items["output"]
        let referral = items["referral"]
        
        switch type {
        case "swap":
            self.type = .trade(trading: .simpleSpot, input: input, output: output)
        case "limit":
            self.type = .trade(trading: .advancedSpot, input: input, output: output)
        case "perps":
            if let market = items["market"] {
                if items["action"] == "open",
                   let side = items["side"],
                   let side = PerpetualOrderSide(rawValue: side)
                {
                    var leverage: Int?
                    if let value = items["leverage"],
                       let decimalValue = Decimal(string: value, locale: .enUSPOSIX),
                       decimalValue > 0
                    {
                        leverage = NSDecimalNumber(decimal: decimalValue).intValue
                    }
                    
                    var margin: Decimal?
                    if let value = items["margin"],
                       let decimalValue = Decimal(string: value, locale: .enUSPOSIX),
                       decimalValue > 0
                    {
                        margin = decimalValue
                    }
                    
                    let position = LeaderPosition(
                        marketID: market,
                        side: side,
                        leverage: leverage,
                        margin: margin,
                        id: items["leader_position"],
                    )
                    self.type = .perpsAction(position)
                } else {
                    self.type = .perpsMarket(id: market)
                }
            } else {
                self.type = .trade(trading: .perpetualFutures, input: input, output: output)
            }
        default:
            self.type = .trade(trading: nil, input: input, output: output)
        }
        self.referral = referral
    }
    
}
