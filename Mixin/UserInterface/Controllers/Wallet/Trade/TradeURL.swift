import Foundation

struct TradeURL {
    
    enum TradingType {
        case perps(product: String)
        case spot(trading: TradeViewController.Trading?, input: String?, output: String?)
    }
    
    let type: TradingType
    let referral: String?
    
    init?(queryItems: [URLQueryItem]?) {
        var type, input, output, product, referral: String?
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
                case "product":
                    product = item.value
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
            if let product {
                self.type = .perps(product: product)
            } else {
                return nil
            }
        default:
            return nil
        }
        self.referral = referral
    }
    
}
