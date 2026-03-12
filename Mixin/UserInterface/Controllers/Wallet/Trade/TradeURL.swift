import Foundation

struct TradeURL {
    
    enum TradingType {
        case perps(market: String)
        case spot(trading: TradeViewController.Trading?, input: String?, output: String?)
    }
    
    let type: TradingType
    let referral: String?
    
    init?(queryItems: [URLQueryItem]?) {
        var type, input, output, market, referral: String?
        if let queryItems {
            for item in queryItems {
                switch item.name {
                case "type":
                    type = item.value
                case "input":
                    input = item.value
                case "output":
                    output = item.value
                case "referral":
                    referral = item.value
                case "market":
                    market = item.value
                default:
                    break
                }
            }
        }
        switch type {
        case "swap":
            self.type = .spot(trading: .simpleSpot, input: input, output: output)
        case "limit":
            self.type = .spot(trading: .advancedSpot, input: input, output: output)
        case "perps":
            if let market {
                self.type = .perps(market: market)
            } else {
                return nil
            }
        default:
            self.type = .spot(trading: nil, input: input, output: output)
        }
        self.referral = referral
    }
    
}
