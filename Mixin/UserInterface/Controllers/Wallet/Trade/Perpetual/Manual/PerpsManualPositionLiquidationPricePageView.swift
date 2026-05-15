import SwiftUI
import MixinServices

struct PerpsManualPositionLiquidationPricePageView: View {
    
    private let marginSymbol = "USDT"
    private let assetSymbol = "SOL"
    private let entryPrice: Decimal = 100
    
    private let priceFormatStyle = Decimal.FormatStyle.Currency
        .currency(code: "USD")
        .presentation(.narrow)
        .precision(.fractionLength(0))
        .rounded(rule: .towardZero)
    
    @State private var side: PerpetualOrderSide = .long
    @State private var leverageMultiplier: Decimal = 10
    
    private var liquidationPrice: Decimal {
        PerpetualChangeSimulation.liquidationPrice(
            side: side,
            entryPrice: entryPrice,
            leverageMultiplier: leverageMultiplier
        )
    }
    
    var body: some View {
        ManualScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(R.string.localizable.example())
                        .modifier(ManualText(.heading))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(R.string.localizable.perps_product())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Image(R.image.solana_chain)
                                .frame(width: 18, height: 18)
                            Spacer()
                                .frame(width: 4)
                            Text("SOL - USD")
                                .modifier(ManualText(.subheading(R.color.text()!)))
                        }
                        HStack {
                            Text(R.string.localizable.example_direction())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            PerpsManualOrderSideControl(
                                selection: $side
                            ) { side in
                                switch side {
                                case .long:
                                    R.string.localizable.long()
                                case .short:
                                    R.string.localizable.short()
                                }
                            }
                        }
                        HStack {
                            Text(R.string.localizable.example_leverage_multiplier())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            HStack(alignment: .center, spacing: 6) {
                                Button {
                                    leverageMultiplier -= 1
                                } label: {
                                    Image(R.image.stepper_decrease)
                                }
                                .disabled(leverageMultiplier <= 1)
                                
                                Text(PerpetualLeverage.stringRepresentation(multiplier: leverageMultiplier))
                                    .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                                
                                Button {
                                    leverageMultiplier += 1
                                } label: {
                                    Image(R.image.stepper_increase)
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        HStack {
                            Text(R.string.localizable.entry_price())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(entryPrice.formatted(priceFormatStyle))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                        }
                        HStack {
                            Text(R.string.localizable.liquidation_price())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(liquidationPrice.formatted(priceFormatStyle))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                        }
                    }
                }
                .padding(PerpsManual.cardInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(R.color.background()!))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(R.string.localizable.overview())
                        .modifier(ManualText(.heading))
                    Spacer()
                        .frame(height: 10)
                    Text(R.string.localizable.perps_liquidation_price_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.spot_trade_guide_additional_notes())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.perps_liquidation_price_key_point_1(),
                        R.string.localizable.perps_liquidation_price_key_point_2(),
                        R.string.localizable.perps_liquidation_price_key_point_3(),
                    ])
                }
                .padding(PerpsManual.cardInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(R.color.background()!))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
        }
    }
    
}
