import SwiftUI
import RswiftResources
import MixinServices

struct PerpsManualLongPositionProfitView: View {
    
    let title: String
    let change: Decimal
    let marginSymbol: String
    
    @Binding var margin: Decimal
    @Binding var leverageMultiplier: Decimal
    
    private var pnl: String {
        let multipliedChange = change * leverageMultiplier
        return CurrencyFormatter.localizedString(
            from: margin * multipliedChange,
            format: .precision,
            sign: .always,
            symbol: .custom(marginSymbol)
        ) + " (" + PercentageFormatter.string(
            from: multipliedChange,
            format: .pretty,
            sign: .always
        ) + ")"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .modifier(ManualText(.caption1))
            HStack {
                Text(R.string.localizable.example_price_increased())
                    .modifier(ManualText(.caption2))
                Spacer()
                Text(PercentageFormatter.string(from: change, format: .pretty, sign: .never))
                    .modifier(ManualText(.subheading(R.color.text()!)))
            }
            HStack {
                Text(R.string.localizable.pnl())
                    .modifier(ManualText(.caption2))
                Spacer()
                Text(pnl)
                    .modifier(ManualText(.subheading(MarketColor.rising.uiColor), monospacedDigit: true))
            }
        }
    }
    
}
