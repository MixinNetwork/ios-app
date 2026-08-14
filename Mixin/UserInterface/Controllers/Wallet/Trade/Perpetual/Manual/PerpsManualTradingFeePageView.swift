import SwiftUI
import MixinServices

struct PerpsManualTradingFeePageView: View {
    
    private let margin: Decimal = 100
    private let marginSymbol = "USDT"
    private let rate: Decimal = 0.16 / 100
    private let risingPercentage: Decimal = 0.1
    private let fallingPercentage: Decimal = 0.05
    
    @State private var leverageMultiplier: Decimal = 10
    
    private var fee: Decimal {
        margin * leverageMultiplier * rate
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
                        
                        HStack {
                            Text(R.string.localizable.open_fee())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(
                                CurrencyFormatter.localizedString(
                                    from: -fee,
                                    format: .precision,
                                    sign: .always,
                                    symbol: .custom(marginSymbol)
                                ) + " (" + PercentageFormatter.string(
                                    from: rate,
                                    format: .precision,
                                    sign: .never
                                ) + ")"
                            )
                            .modifier(ManualText(.subheading(MarketColor.falling.uiColor)))
                        }
                        HStack {
                            Text(R.string.localizable.close_fee())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(
                                CurrencyFormatter.localizedString(
                                    from: -fee,
                                    format: .precision,
                                    sign: .always,
                                    symbol: .custom(marginSymbol)
                                ) + " (" + PercentageFormatter.string(
                                    from: rate,
                                    format: .precision,
                                    sign: .never
                                ) + ")"
                            )
                            .modifier(ManualText(.subheading(MarketColor.falling.uiColor)))
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        Text(R.string.localizable.example_scene1_increasing())
                            .modifier(ManualText(.caption1))
                        HStack {
                            Text(R.string.localizable.example_price_change())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(PercentageFormatter.string(
                                from: risingPercentage,
                                format: .precision,
                                sign: .always
                            ))
                            .modifier(ManualText(.subheading(MarketColor.rising.uiColor)))
                        }
                        HStack {
                            Text(R.string.localizable.pnl())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(CurrencyFormatter.localizedString(
                                from: margin * leverageMultiplier * risingPercentage - fee * 2,
                                format: .precision,
                                sign: .always,
                                symbol: .custom(marginSymbol)
                            ))
                            .modifier(ManualText(.subheading(MarketColor.rising.uiColor)))
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        
                        Text(R.string.localizable.example_scene2_decreasing())
                            .modifier(ManualText(.caption1))
                        HStack {
                            Text(R.string.localizable.example_price_change())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(PercentageFormatter.string(
                                from: -fallingPercentage,
                                format: .precision,
                                sign: .always
                            ))
                            .modifier(ManualText(.subheading(MarketColor.falling.uiColor)))
                        }
                        HStack {
                            Text(R.string.localizable.pnl())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(CurrencyFormatter.localizedString(
                                from: -margin * leverageMultiplier * fallingPercentage - fee * 2,
                                format: .precision,
                                sign: .always,
                                symbol: .custom(marginSymbol)
                            ))
                            .modifier(ManualText(.subheading(MarketColor.falling.uiColor)))
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
                    Text(R.string.localizable.perps_trading_fee_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.pnl())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.perps_trading_fee_pnl_1(),
                        R.string.localizable.perps_trading_fee_pnl_2(),
                        R.string.localizable.perps_trading_fee_pnl_3(),
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
