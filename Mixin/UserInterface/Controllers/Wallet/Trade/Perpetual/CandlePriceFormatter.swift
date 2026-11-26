import UIKit
import MixinServices

enum CandlePriceFormatMode {
    /// Decimal formatting with grouping separator, fixed zero-padded decimals, HALF_UP rounding, and no currency symbol.
    case decimal(priceScale: Int?)
    /// Existing currency style (e.g., PerpetualMarket.userDisplayPriceFormatStyle(scale:)).
    case currencyStyle(Decimal.FormatStyle.Currency)
    /// Custom formatting closure receiving (value, derivedDecimals).
    case custom((Decimal, Int) -> String)
}

struct CandleChartLabels: Equatable {
    
    let open: String
    let close: String
    let high: String
    let low: String
    let date: String
    
    static let `default` = CandleChartLabels(
        open: "Open",
        close: "Close",
        high: "High",
        low: "Low",
        date: "Date"
    )
    
    init(open: String, close: String, high: String, low: String, date: String) {
        self.open = open
        self.close = close
        self.high = high
        self.low = low
        self.date = date
    }
    
}

enum CandlePriceFormatter {
    
    static let minimumAxisWidth: CGFloat = 48
    static let axisHorizontalPadding: CGFloat = 16
    
    static func priceDecimals(candles: [PerpetualCandleViewModel], priceScale: Int?) -> Int {
        if let priceScale {
            return max(0, min(18, priceScale))
        }
        guard !candles.isEmpty else {
            return 2
        }
        var maxFractionDigits = 0
        for candle in candles {
            let digits = significantFractionDigits(of: candle.close.decimalValue)
            if digits > maxFractionDigits {
                maxFractionDigits = digits
            }
        }
        return max(0, min(10, maxFractionDigits))
    }
    
    static func format(
        _ value: Decimal,
        mode: CandlePriceFormatMode,
        candles: [PerpetualCandleViewModel],
        locale: Locale = .current
    ) -> String {
        switch mode {
        case .decimal(let priceScale):
            let decimals = priceDecimals(candles: candles, priceScale: priceScale)
            return formatDecimal(value, decimals: decimals, locale: locale)
        case .currencyStyle(let style):
            return value.formatted(style)
        case .custom(let formatter):
            let decimals = priceDecimals(candles: candles, priceScale: nil)
            return formatter(value, decimals)
        }
    }
    
    static func formatDecimal(
        _ value: Decimal,
        decimals: Int,
        locale: Locale = .current
    ) -> String {
        let clampedDecimals = max(0, min(18, decimals))
        let style = Decimal.FormatStyle.number
            .locale(locale)
            .grouping(.automatic)
            .precision(.fractionLength(clampedDecimals))
            .rounded(rule: .toNearestOrAwayFromZero)
        return value.formatted(style)
    }
    
    static func formatChangePercentage(
        open: Decimal,
        close: Decimal,
        locale: Locale = .current
    ) -> String {
        let isRising = close >= open
        let prefix = isRising ? "↑" : "↓"
        guard open != 0 else {
            let zero = Decimal(0).formatted(
                Decimal.FormatStyle.number
                    .locale(locale)
                    .grouping(.never)
                    .precision(.fractionLength(2))
            )
            return "\(prefix)\(zero)%"
        }
        let change = abs((close - open) / open * 100)
        let formatted = change.formatted(
            Decimal.FormatStyle.number
                .locale(locale)
                .grouping(.never)
                .precision(.fractionLength(2))
                .rounded(rule: .toNearestOrAwayFromZero)
        )
        return "\(prefix)\(formatted)%"
    }
    
    static func measureAxisWidth(
        candles: [PerpetualCandleViewModel],
        latestPrice: Decimal?,
        mode: CandlePriceFormatMode,
        font: UIFont = .systemFont(ofSize: 11),
        locale: Locale = .current
    ) -> CGFloat {
        var candidates: [Decimal] = []
        if !candles.isEmpty {
            var globalHigh = candles[0].high.decimalValue
            var globalLow = candles[0].low.decimalValue
            for candle in candles {
                let high = candle.high.decimalValue
                let low = candle.low.decimalValue
                if high > globalHigh {
                    globalHigh = high
                }
                if low < globalLow {
                    globalLow = low
                }
            }
            candidates.append(globalHigh)
            candidates.append(globalLow)
        }
        if let latestPrice, !latestPrice.isNaN {
            candidates.append(latestPrice)
        }
        guard !candidates.isEmpty else {
            return minimumAxisWidth
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var widest: CGFloat = 0
        for candidate in candidates {
            let text = format(candidate, mode: mode, candles: candles, locale: locale)
            let width = (text as NSString).size(withAttributes: attributes).width
            if width > widest {
                widest = width
            }
        }
        return max(ceil(widest) + axisHorizontalPadding, minimumAxisWidth)
    }
    
    private static func significantFractionDigits(of decimal: Decimal) -> Int {
        let plain = decimal.formatted(
            Decimal.FormatStyle.number
                .locale(.enUSPOSIX)
                .grouping(.never)
                .sign(strategy: .never)
                .precision(.fractionLength(0...18))
        )
        guard let dotIndex = plain.firstIndex(of: ".") else {
            return 0
        }
        var fractional = plain[plain.index(after: dotIndex)...]
        while fractional.last == "0" {
            fractional = fractional.dropLast()
        }
        return fractional.count
    }
    
}
