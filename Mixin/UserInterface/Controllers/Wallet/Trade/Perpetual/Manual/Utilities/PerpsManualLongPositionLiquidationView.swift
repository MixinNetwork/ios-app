import SwiftUI
import RswiftResources
import MixinServices

struct PerpsManualLongPositionLiquidationView: View {
    
    let title: String
    let marginSymbol: String
    
    @Binding var margin: Decimal
    @Binding var leverageMultiplier: Decimal
    
    private var change: String {
        PercentageFormatter.string(
            from: -1 / leverageMultiplier,
            format: .pretty,
            sign: .always
        )
    }
    
    private var loss: String {
        CurrencyFormatter.localizedString(
            from: -margin,
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
                Text(R.string.localizable.example_price_change())
                    .modifier(ManualText(.caption2))
                Spacer()
                Text(change)
                    .modifier(ManualText(.subheading(MarketColor.falling.uiColor)))
            }
            HStack {
                Text(R.string.localizable.pnl())
                    .modifier(ManualText(.caption2))
                Spacer()
                Text(loss)
                    .modifier(ManualText(.subheading(MarketColor.falling.uiColor)))
            }
        }
    }
    
}
