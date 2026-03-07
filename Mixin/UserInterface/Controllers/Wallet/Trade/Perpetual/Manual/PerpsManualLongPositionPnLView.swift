import SwiftUI
import RswiftResources
import MixinServices

struct PerpsManualLongPositionPnLView: View {
    
    let title: String
    let change: Decimal
    let marginSymbol: String
    
    @Binding var margin: Decimal
    @Binding var leverageMultiplier: Decimal
    
    private var pnl: String {
        CurrencyFormatter.localizedString(
            from: margin * leverageMultiplier * change,
            format: .precision,
            sign: .always,
            symbol: .custom(marginSymbol)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .modifier(ManualText(.caption1))
            HStack {
                if change >= 0 {
                    Text(R.string.localizable.example_price_increased())
                        .modifier(ManualText(.caption2))
                } else {
                    Text(R.string.localizable.example_price_decreased())
                        .modifier(ManualText(.caption2))
                }
                Spacer()
                Text(PercentageFormatter.string(from: change, sign: .never))
                    .modifier(ManualText(.subheading(R.color.text()!)))
            }
            HStack {
                Text(R.string.localizable.pnl())
                    .modifier(ManualText(.caption2))
                Spacer()
                if change >= 0 {
                    Text(pnl + " (" + PercentageFormatter.string(from: change, sign: .always) + ")")
                        .modifier(ManualText(.subheading(MarketColor.rising.uiColor), monospacedDigit: true))
                } else {
                    Text(pnl)
                        .modifier(ManualText(.subheading(MarketColor.falling.uiColor), monospacedDigit: true))
                }
            }
        }
    }
    
}
