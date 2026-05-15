import SwiftUI
import RswiftResources
import MixinServices

struct PerpsManualCalculatingPnLView: View {
    
    enum Direction {
        case long
        case short
    }
    
    let direction: Direction
    let leverage: Decimal
    let margin: Decimal
    let marginSymbol: String
    let changeStep: Decimal
    
    @State
    var change: Decimal = 0.1
    
    private var changeColor: MarketColor {
        change >= 0 ? .rising : .falling
    }
    
    private var pnlPercentage: Decimal {
        switch direction {
        case .long:
            change * leverage
        case .short:
            -change * leverage
        }
    }
    
    private var pnlColor: MarketColor {
        pnlPercentage >= 0 ? .rising : .falling
    }
    
    private var displayPnL: String {
        let pnl = margin * pnlPercentage
        let localizedPnL = CurrencyFormatter.localizedString(
            from: pnl,
            format: .precision,
            sign: .always,
            symbol: .custom(marginSymbol)
        )
        if pnl >= 0 {
            let percentage = PercentageFormatter.string(
                from: pnlPercentage,
                format: .pretty,
                sign: .always
            )
            return localizedPnL + "(" + percentage + ")"
        } else {
            return localizedPnL
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(R.string.localizable.example_price_change())
                    .modifier(ManualText(.caption2))
                Spacer()
                HStack(alignment: .center, spacing: 6) {
                    Button {
                        change -= changeStep
                    } label: {
                        Image(R.image.stepper_decrease)
                    }
                    
                    Text(PercentageFormatter.string(from: change, format: .pretty, sign: .always))
                        .modifier(ManualText(.subheading(changeColor.uiColor), monospacedDigit: true))
                    
                    Button {
                        change += changeStep
                    } label: {
                        Image(R.image.stepper_increase)
                    }
                }
            }
            HStack {
                Text(R.string.localizable.pnl())
                    .modifier(ManualText(.caption2))
                Spacer()
                Text(displayPnL)
                    .modifier(ManualText(.subheading(pnlColor.uiColor), monospacedDigit: true))
            }
        }
    }
    
}
