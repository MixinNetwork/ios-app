import SwiftUI
import MixinServices

struct PerpsManualTPSLPageView: View {
    
    private let margin: Decimal = 1000
    private let marginSymbol = "USDT"
    private let assetSymbol = "SOL"
    private let assetPrice: Decimal = 74.62
    private let leverageMultiplier: Decimal = 10
    private let entryPrice: Decimal = 100
    private let takeProfitPrice: Decimal = 110
    private let stopLossPrice: Decimal = 95
    
    private let priceFormatStyle = Decimal.FormatStyle.Currency
        .currency(code: "USD")
        .presentation(.narrow)
        .precision(.fractionLength(0))
        .rounded(rule: .towardZero)
    
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
                            Text(PerpetualLeverage.stringRepresentation(multiplier: leverageMultiplier))
                                .modifier(ManualText(.subheading(R.color.text()!)))
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
                        HStack {
                            Text(R.string.localizable.entry_price())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(entryPrice.formatted(priceFormatStyle))
                            .modifier(ManualText(.subheading(R.color.text()!)))
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        Text(R.string.localizable.take_profit())
                            .modifier(ManualText(.caption1))
                        HStack {
                            Text(R.string.localizable.trigger_price())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(takeProfitPrice.formatted(priceFormatStyle))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                        }
                        HStack {
                            Text(R.string.localizable.pnl())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(
                                CurrencyFormatter.localizedString(
                                    from: margin * changePercentage(price: takeProfitPrice),
                                    format: .precision,
                                    sign: .always,
                                    symbol: .custom(marginSymbol)
                                )
                                + " ("
                                + PercentageFormatter.string(
                                    from: changePercentage(price: takeProfitPrice),
                                    format: .precision,
                                    sign: .always
                                )
                                + ")"
                            )
                            .modifier(ManualText(.subheading(MarketColor.rising.uiColor), monospacedDigit: true))
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        Text(R.string.localizable.stop_loss())
                            .modifier(ManualText(.caption1))
                        HStack {
                            Text(R.string.localizable.trigger_price())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(stopLossPrice.formatted(priceFormatStyle))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                        }
                        HStack {
                            Text(R.string.localizable.pnl())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(
                                CurrencyFormatter.localizedString(
                                    from: margin * changePercentage(price: stopLossPrice),
                                    format: .precision,
                                    sign: .always,
                                    symbol: .custom(marginSymbol)
                                )
                            )
                            .modifier(ManualText(.subheading(MarketColor.falling.uiColor), monospacedDigit: true))
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
                    Text(R.string.localizable.perps_tpsl_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.pnl())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.perps_scene_tp_triggered(),
                        R.string.localizable.perps_scene_sl_triggered(),
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
    
    private func changePercentage(price: Decimal) -> Decimal {
        (price - entryPrice) * leverageMultiplier / entryPrice
    }
    
}
