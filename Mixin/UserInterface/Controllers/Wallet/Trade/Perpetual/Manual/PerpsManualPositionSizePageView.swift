import SwiftUI
import MixinServices

struct PerpsManualPositionSizePageView: View {
    
    private let marginStep: Decimal = 100
    private let marginSymbol = "USDT"
    private let assetSymbol = "SOL"
    private let assetPrice: Decimal = 74.62
    
    @State private var margin: Decimal = 1000
    @State private var leverageMultiplier: Decimal = 10
    
    var body: some View {
        ManualScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(R.string.localizable.example())
                        .modifier(ManualText(.heading))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(R.string.localizable.example_perpetual())
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
                        HStack {
                            Text(R.string.localizable.example_amount())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            HStack(alignment: .center, spacing: 6) {
                                Button {
                                    margin -= marginStep
                                } label: {
                                    Image(R.image.stepper_decrease)
                                }
                                .disabled(margin <= marginStep)
                                
                                Text(CurrencyFormatter.localizedString(
                                    from: margin,
                                    format: .precision,
                                    sign: .never,
                                    symbol: .custom(marginSymbol)
                                ))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                                
                                Button {
                                    margin += marginStep
                                } label: {
                                    Image(R.image.stepper_increase)
                                }
                            }
                        }
                        HStack {
                            Text(R.string.localizable.position_size())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(CurrencyFormatter.localizedString(
                                from: margin * leverageMultiplier / assetPrice,
                                format: .precision,
                                sign: .never,
                                symbol: .custom(assetSymbol)
                            ))
                            .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        PerpsManualLongPositionProfitView(
                            title: R.string.localizable.example_scene1_rises(),
                            change: 0.1,
                            marginSymbol: marginSymbol,
                            margin: $margin,
                            leverageMultiplier: $leverageMultiplier,
                        )
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        PerpsManualLongPositionLiquidationView(
                            title: R.string.localizable.example_scene2_falls(),
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
                    Text(R.string.localizable.perps_position_size_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.purpose())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.perps_position_size_purpose_1(),
                        R.string.localizable.perps_position_size_purpose_2(),
                    ])
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.risk_notice())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.perps_position_size_risk_1(),
                        R.string.localizable.perps_position_size_risk_2(),
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
