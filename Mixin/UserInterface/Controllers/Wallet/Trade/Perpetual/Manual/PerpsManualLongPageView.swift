import SwiftUI
import RswiftResources
import MixinServices

struct PerpsManualLongPageView: View {
    
    private let margin: Decimal = 1000
    private let marginSymbol = "USDT"
    private let leverageMultiplier: Decimal = 10
    
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
                            Image(R.image.bitcoin_chain)
                                .frame(width: 18, height: 18)
                            Spacer()
                                .frame(width: 4)
                            Text("BTC - USD")
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
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        PerpsManualCalculatingPnLView(
                            title: R.string.localizable.example_scene1_rises(),
                            direction: .long,
                            leverage: leverageMultiplier,
                            margin: margin,
                            marginSymbol: marginSymbol,
                            changeStep: 0.01,
                            change: 0.1
                        )
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        PerpsManualCalculatingPnLView(
                            title: R.string.localizable.example_scene2_falls(),
                            direction: .long,
                            leverage: leverageMultiplier,
                            margin: margin,
                            marginSymbol: marginSymbol,
                            changeStep: 0.01,
                            change: -0.1
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
                    Text(R.string.localizable.perps_long_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.pnl())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.pnl_rule_price_rise_profit(),
                        R.string.localizable.pnl_rule_price_fall_loss(),
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
