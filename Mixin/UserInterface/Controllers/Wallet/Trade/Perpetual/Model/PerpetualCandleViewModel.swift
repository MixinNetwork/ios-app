import Foundation
import MixinServices

// All prices are in local currency
struct PerpetualCandleViewModel {
    
    let time: String
    let open: NSDecimalNumber
    let high: NSDecimalNumber
    let low: NSDecimalNumber
    let close: NSDecimalNumber
    
}

extension PerpetualCandleViewModel {
    
    // Returns nil if candles are bad
    static func viewModels(
        timeFrame: PerpetualTimeFrame,
        candle: PerpetualMarketCandle
    ) -> [PerpetualCandleViewModel]? {
        let drawingItems = candle.items
        let dateFormatter: DateFormatter = switch timeFrame {
        case .oneMinute, .fiveMinutes, .oneHour, .fourHours:
                .shortTimeOnly
        case .oneDay, .oneWeek:
                .shortDateOnly
        }
        let numberFormatter: NumberFormatter = .enUSPOSIXDecimal
        let currencyRate = Currency.current.decimalRate as NSDecimalNumber
        
        var entries: [PerpetualCandleViewModel] = []
        entries.reserveCapacity(drawingItems.count)
        for item in drawingItems {
            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp / 1000))
            let open = numberFormatter.number(from: item.open) as? NSDecimalNumber
            let close = numberFormatter.number(from: item.close) as? NSDecimalNumber
            let high = numberFormatter.number(from: item.high) as? NSDecimalNumber
            let low = numberFormatter.number(from: item.low) as? NSDecimalNumber
            guard let open, let close, let high, let low else {
                return nil
            }
            let entry = PerpetualCandleViewModel(
                time: dateFormatter.string(from: date),
                open: open.multiplying(by: currencyRate),
                high: high.multiplying(by: currencyRate),
                low: low.multiplying(by: currencyRate),
                close: close.multiplying(by: currencyRate),
            )
            entries.append(entry)
        }
        return entries
    }
    
}
