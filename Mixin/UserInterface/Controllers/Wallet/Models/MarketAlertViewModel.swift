import UIKit
import MixinServices

final class MarketAlertViewModel {
    
    let coin: MarketAlertCoin
    let description: String
    var alerts: [AlertViewModel]
    
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
            self.description = R.string.localizable.current_price(usdPrice + " USD")
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
            self.icon = alert.type.displayType.icon
            if let value = Decimal(string: alert.value, locale: .enUSPOSIX) {
                let localizedValue = switch alert.type.valueType {
                case .absolute:
                    CurrencyFormatter.localizedString(
                        from: value,
                        format: .fiatMoneyPrice,
                        sign: .never
                    ) + " USD"
                case .percentage:
                    NumberFormatter.percentage.string(decimal: value) ?? alert.value
                }
                self.title = alert.type.valueRepresentation(value: localizedValue)
            } else {
                self.title = ""
            }
            self.subtitle = alert.frequency.name
            self.alert = alert
        }
        
    }
    
}
