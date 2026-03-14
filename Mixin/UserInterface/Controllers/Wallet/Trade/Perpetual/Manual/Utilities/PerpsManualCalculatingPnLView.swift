import SwiftUI
import RswiftResources
import MixinServices

struct PerpsManualCalculatingPnLView: View {
    
    enum Direction {
        case long
        case short
    }
    
    let title: String
    let direction: Direction
    let leverage: Decimal
    let margin: Decimal
    let marginSymbol: String
    let changeStep: Decimal
    
    @State
    var change: Decimal = 0.1
    
    private var canDecrease: Bool {
        if change > 0 {
            change > changeStep
        } else {
            change < -changeStep
        }
    }
    
    private var canIncrease: Bool {
        switch direction {
        case .long:
            if change > 0 {
                true
            } else {
                (change - changeStep) * leverage >= -1
            }
        case .short:
            if change > 0 {
                (change + changeStep) * leverage <= 1
            } else {
                change < changeStep
            }
        }
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
        pnlPercentage > 0 ? .rising : .falling
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
                HStack(alignment: .center, spacing: 6) {
                    Button {
                        guard canDecrease else {
                            return
                        }
                        if change < 0 {
                            change += changeStep
                        } else {
                            change -= changeStep
                        }
                    } label: {
                        Image(R.image.stepper_decrease)
                    }
                    .disabled(!canDecrease)
                    
                    Text(PercentageFormatter.string(from: change, format: .pretty, sign: .never))
                        .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                    
                    Button {
                        guard canIncrease else {
                            return
                        }
                        if change > 0 {
                            change += changeStep
                        } else {
                            change -= changeStep
                        }
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
