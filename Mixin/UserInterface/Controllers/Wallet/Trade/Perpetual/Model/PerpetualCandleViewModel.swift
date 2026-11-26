import Foundation
import MixinServices

// All prices are in local currency
struct PerpetualCandleViewModel: Equatable {
    
    let timestamp: Int64
    let time: String
    let open: NSDecimalNumber
    let high: NSDecimalNumber
    let low: NSDecimalNumber
    let close: NSDecimalNumber
    
    init(
        timestamp: Int64,
        time: String,
        open: NSDecimalNumber,
        high: NSDecimalNumber,
        low: NSDecimalNumber,
        close: NSDecimalNumber
    ) {
        self.timestamp = Self.normalizedTimestampMillis(timestamp)
        self.time = time
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }
    
}

extension PerpetualCandleViewModel {
    
    static func normalizedTimestampMillis(_ rawTimestamp: Int64) -> Int64 {
        rawTimestamp < 1_000_000_000_000 ? rawTimestamp * 1000 : rawTimestamp
    }
    
    // Returns nil if candles are bad
    static func viewModels(
        timeFrame: PerpetualTimeFrame,
        candle: PerpetualMarketCandle
    ) -> [PerpetualCandleViewModel]? {
        let drawingItems = candle.items
        let dateFormatter: DateFormatter = if timeFrame.usesDateOnlyFormat {
            .shortDateOnly
        } else {
            .shortTimeOnly
        }
        
        var entries: [PerpetualCandleViewModel] = []
        entries.reserveCapacity(drawingItems.count)
        for item in drawingItems {
            let timestamp = normalizedTimestampMillis(Int64(item.timestamp))
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
            
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
                timestamp: timestamp,
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
    
    static func withLivePrice(
        candles: [PerpetualCandleViewModel],
        lastPrice: Decimal?,
        timeFrame: PerpetualTimeFrame,
        nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> [PerpetualCandleViewModel] {
        guard let last = candles.last,
              let lastPrice,
              !lastPrice.isNaN,
              lastPrice > 0
        else {
            return candles
        }
        let lastStart = normalizedTimestampMillis(last.timestamp)
        let period = timeFrame.durationMillis
        guard nowMillis >= lastStart, nowMillis < lastStart + period else {
            return candles
        }
        let liveNumber = lastPrice as NSDecimalNumber
        let updatedHigh = last.high.compare(liveNumber) == .orderedAscending ? liveNumber : last.high
        let updatedLow = last.low.compare(liveNumber) == .orderedDescending ? liveNumber : last.low
        let updatedLast = PerpetualCandleViewModel(
            timestamp: lastStart,
            time: last.time,
            open: last.open,
            high: updatedHigh,
            low: updatedLow,
            close: liveNumber
        )
        var result = candles
        result[result.count - 1] = updatedLast
        return result
    }
    
}
