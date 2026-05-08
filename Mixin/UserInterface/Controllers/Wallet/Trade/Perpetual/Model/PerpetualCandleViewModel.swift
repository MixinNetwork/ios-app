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
        
        var entries: [PerpetualCandleViewModel] = []
        entries.reserveCapacity(drawingItems.count)
        for item in drawingItems {
            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp / 1000))
            
            // Do not use NumberFormatter here
            // It lose precision like floating point numbers for no reason
            // Even if `generatesDecimalNumbers` is true
            let open = Decimal(string: item.open, locale: .enUSPOSIX)
            let close = Decimal(string: item.close, locale: .enUSPOSIX)
            let high = Decimal(string: item.high, locale: .enUSPOSIX)
            let low = Decimal(string: item.low, locale: .enUSPOSIX)
            
            guard let open, let close, let high, let low else {
                return nil
            }
            let entry = PerpetualCandleViewModel(
                time: dateFormatter.string(from: date),
                open: open as NSDecimalNumber,
                high: high as NSDecimalNumber,
                low: low as NSDecimalNumber,
                close: close as NSDecimalNumber,
            )
            entries.append(entry)
        }
        return entries
    }
    
}
