import UIKit
import MixinServices

final class MarketAlertViewModel {
    
    struct Alert {
        
        let icon: UIImage
        let title: String
        let subtitle: String
        var alert: MarketAlert
        
        init(alert: MarketAlert) {
            switch alert.type {
            case .priceReached:
                self.icon = R.image.market_alert_volume()!
            case .priceIncreased, .percentageIncreased:
                self.icon = R.image.market_alert_increase()!
            case .priceDecreased, .percentageDecreased:
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
                    "\(R.string.localizable.alert_type_price_increased()) >= \(localizedValue)"
                case .percentageDecreased:
                    "\(R.string.localizable.alert_type_price_decreased()) <= \(localizedValue)"
                }
            } else {
                self.title = ""
            }
            self.subtitle = alert.frequency.description
            self.alert = alert
        }
        
    }
    
    let assetID: String
    let iconURL: URL?
    let name: String
    let description: String
    var alerts: [Alert]
    
    var isExpanded = false
    
    init(token: MarketAlertToken, alerts: [MarketAlert]) {
        self.assetID = token.assetID
        self.iconURL = URL(string: token.iconURL)
        self.name = token.name
        if let price = Decimal(string: token.usdPrice, locale: .enUSPOSIX) {
            let usdPrice = CurrencyFormatter.localizedString(
                from: price,
                format: .fiatMoneyPrice,
                sign: .never
            )
            self.description = R.string.localizable.current_price(usdPrice)
        } else {
            self.description = ""
        }
        self.alerts = alerts.map(Alert.init(alert:))
    }
    
}
