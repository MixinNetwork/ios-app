import Foundation
import MixinServices

extension MarketAlert {
    
    enum Action: String {
        case pause
        case resume
        case delete
    }
    
}

extension MarketAlert.AlertType {
    
    var name: String {
        switch self {
        case .priceReached:
            R.string.localizable.alert_type_price_reached()
        case .priceIncreased:
            R.string.localizable.alert_type_price_increased()
        case .priceDecreased:
            R.string.localizable.alert_type_price_decreased()
        case .percentageIncreased:
            R.string.localizable.alert_type_percentage_increased()
        case .percentageDecreased:
            R.string.localizable.alert_type_percentage_decreased()
        }
    }
    
    var description: String {
        switch self {
        case .priceReached:
            R.string.localizable.alert_type_price_reached_description()
        case .priceIncreased:
            R.string.localizable.alert_type_price_increased_description()
        case .priceDecreased:
            R.string.localizable.alert_type_price_decreased_description()
        case .percentageIncreased:
            R.string.localizable.alert_type_percentage_increased_description()
        case .percentageDecreased:
            R.string.localizable.alert_type_percentage_decreased_description()
        }
    }
    
    func valueRepresentation(value: String) -> String {
        switch self {
        case .priceReached:
            R.string.localizable.alert_type_price_reached_value(value)
        case .priceIncreased:
            R.string.localizable.alert_type_price_increased_value(value)
        case .priceDecreased:
            R.string.localizable.alert_type_price_decreased_value(value)
        case .percentageIncreased:
            R.string.localizable.alert_type_percentage_increased_value(value)
        case .percentageDecreased:
            R.string.localizable.alert_type_percentage_decreased_value(value)
        }
    }
    
}

extension MarketAlert.AlertDisplayType {
    
    var icon: UIImage {
        switch self {
        case .constant:
            R.image.market_alert_reach()!
        case .increasing:
            R.image.market_alert_increase()!
        case .decreasing:
            R.image.market_alert_decrease()!
        }
    }
    
}

extension MarketAlert.AlertFrequency {
    
    var icon: UIImage {
        switch self {
        case .every:
            R.image.alert_frequency_every()!
        case .daily:
            R.image.alert_frequency_daily()!
        case .once:
            R.image.alert_frequency_once()!
        }
    }
    
    var name: String {
        switch self {
        case .every:
            R.string.localizable.alert_frequency_every()
        case .daily:
            R.string.localizable.alert_frequency_daily()
        case .once:
            R.string.localizable.alert_frequency_once()
        }
    }
    
    var description: String {
        switch self {
        case .every:
            R.string.localizable.alert_frequency_every_description()
        case .daily:
            R.string.localizable.alert_frequency_daily_description()
        case .once:
            R.string.localizable.alert_frequency_once_description()
        }
    }
    
}
