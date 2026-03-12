import SwiftUI
import MixinServices

struct PerpsManualLeveragePageView: View {
    
    private let marginSymbol = "USDT"
    
    @State private var margin: Decimal = 1000
    @State private var leverageMultiplier: Decimal = 10
    
    var body: some View {
        ZStack {
            Color(R.color.background_secondary)
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(R.string.localizable.example())
                        .modifier(ManualText(.heading))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(R.string.localizable.example_open_position())
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
                            Text(R.string.localizable.long())
                                .modifier(ScaledFont(size: 12, weight: .medium, relativeTo: .body))
                                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .background(Color(MarketColor.rising.uiColor))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        HStack {
                            Text(R.string.localizable.leverage_multiplier())
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
                        HStack {
                            Text(R.string.localizable.example_margin())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(CurrencyFormatter.localizedString(
                                from: margin,
                                format: .precision,
                                sign: .never,
                                symbol: .custom(marginSymbol)
                            ))
                            .modifier(ManualText(.subheading(R.color.text()!)))
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        PerpsManualLongPositionProfitView(
                            title: R.string.localizable.example_scene1_increasing(),
                            change: 0.1,
                            marginSymbol: marginSymbol,
                            margin: $margin,
                            leverageMultiplier: $leverageMultiplier,
                        )
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        PerpsManualLongPositionLiquidationView(
                            title: R.string.localizable.example_scene2_decreasing(),
                            marginSymbol: marginSymbol,
                            margin: $margin,
                            leverageMultiplier: $leverageMultiplier,
                        )
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
                    Text(R.string.localizable.perps_leverage_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.impact_on_pnl())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.impact_on_pnl_1(),
                        R.string.localizable.impact_on_pnl_2(),
                    ])
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.risk_notice())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.perps_leverage_risk_notice(),
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
