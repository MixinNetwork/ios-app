import Foundation
import MixinServices

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
        case perpsOpen(LeaderPosition)
        case perpsAddMargin(marketID: String, value: Decimal?)
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
                let action = items["action"]
                if action == "open",
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
                    self.type = .perpsOpen(position)
                } else if action == "add_margin" {
                    var value: Decimal?
                    if let margin = items["margin"],
                       let decimalMargin = Decimal(string: margin, locale: .enUSPOSIX),
                       decimalMargin > 0
                    {
                        value = withUnsafePointer(to: decimalMargin) { margin in
                            var rounded: Decimal = 0
                            NSDecimalRound(&rounded, margin, Int(MixinToken.internalPrecision), .down)
                            return rounded
                        }
                    }
                    self.type = .perpsAddMargin(marketID: market, value: value)
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
