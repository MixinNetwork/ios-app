import UIKit
import MixinServices

final class MarketAlertViewModel {
    
    let coin: MarketAlertCoin
    let description: String
    var alerts: [AlertViewModel]
    
    var isExpanded = false
    
    var iconURL: URL? {
        URL(string: coin.iconURL)
    }
    
    init(coin: MarketAlertCoin, alerts: [MarketAlert]) {
        self.coin = coin
        if let price = Decimal(string: coin.currentPrice, locale: .enUSPOSIX) {
            let usdPrice = CurrencyFormatter.localizedString(
                from: price,
                format: .fiatMoneyPrice,
                sign: .never
            )
            self.description = R.string.localizable.current_price(usdPrice)
        } else {
            self.description = ""
        }
        self.alerts = alerts.map(AlertViewModel.init(alert:))
    }
    
}

extension MarketAlertViewModel {
    
    struct AlertViewModel {
        
        let icon: UIImage
        let title: String
        let subtitle: String
        var alert: MarketAlert
        
        init(alert: MarketAlert) {
            switch alert.type.displayType {
            case .constant:
                self.icon = R.image.market_alert_volume()!
            case .increasing:
                self.icon = R.image.market_alert_increase()!
            case .decreasing:
                self.icon = R.image.market_alert_decrease()!
            }
            if let value = Decimal(string: alert.value, locale: .enUSPOSIX) {
                let localizedValue = switch alert.type {
                case .priceReached, .priceIncreased, .priceDecreased:
                    CurrencyFormatter.localizedString(
                        from: value,
                        format: .fiatMoneyPrice,
                        sign: .never
                    )
                case .percentageIncreased, .percentageDecreased:
                    NumberFormatter.percentage.string(decimal: value) ?? alert.value
                }
                self.title = switch alert.type {
                case .priceReached:
                    "\(R.string.localizable.price()) = \(localizedValue)"
                case .priceIncreased:
                    "\(R.string.localizable.price()) >= \(localizedValue)"
                case .priceDecreased:
                    "\(R.string.localizable.price()) <= \(localizedValue)"
                case .percentageIncreased:
                    "\(R.string.localizable.alert_type_percentage_increased()) >= \(localizedValue)"
                case .percentageDecreased:
                    "\(R.string.localizable.alert_type_percentage_decreased()) <= \(localizedValue)"
                }
            } else {
                self.title = ""
            }
            self.subtitle = alert.frequency.description
            self.alert = alert
        }
        
    }
    
}
