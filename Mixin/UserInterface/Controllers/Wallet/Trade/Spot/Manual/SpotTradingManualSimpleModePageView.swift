import SwiftUI
import RswiftResources
import MixinServices

struct SpotTradingManualSimpleModePageView: View {
    
    private let payAmountStep: Decimal = 100
    
    @EnvironmentObject private var quote: SpotTradingManual.Quote
    
    @State private var payAmount: Decimal = 1000
    @State private var numeraire: ExchangeRateQuote.Numeraire = .send
    
    private var payAmountCanDecrease: Bool {
        payAmount > payAmountStep
    }
    
    var body: some View {
        ManualScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(R.string.localizable.example())
                        .modifier(ManualText(.heading))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(R.string.localizable.trade_guide_trading_pair())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            HStack(spacing: 4) {
                                SpotTradingTokenView(icon: .usdt, text: "USDT")
                                Text("→")
                                    .modifier(ManualText(.subheading(R.color.text()!)))
                                SpotTradingTokenView(icon: .btc, text: "BTC")
                            }
                        }
                        HStack {
                            Text(R.string.localizable.trade_guide_pay_amount())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            HStack(alignment: .center, spacing: 6) {
                                Button {
                                    guard payAmountCanDecrease else {
                                        return
                                    }
                                    payAmount -= payAmountStep
                                } label: {
                                    Image(R.image.stepper_decrease)
                                }
                                .disabled(!payAmountCanDecrease)
                                
                                Text(CurrencyFormatter.localizedString(
                                    from: payAmount,
                                    format: .fiatMoneyPrice,
                                    sign: .never,
                                    symbol: .custom("USDT")
                                ))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                                
                                Button {
                                    payAmount += payAmountStep
                                } label: {
                                    Image(R.image.stepper_increase)
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        Text(R.string.localizable.trade_guide_market_price())
                            .modifier(ManualText(.body))
                        
                        HStack(spacing: 6) {
                            Text(
                                ExchangeRateQuote.expression(
                                    sendAmount: 1,
                                    sendSymbol: "BTC",
                                    receiveAmount: quote.price,
                                    receiveSymbol: "USDT",
                                    numeraire: numeraire,
                                    format: .fiatMoneyPrice,
                                )
                            )
                            .modifier(ManualText(.caption2))
                            
                            SpotTradingManual.CircularProgressView(
                                progress: $quote.progress
                            )
                            .frame(width: 12, height: 12, alignment: .center)
                            
                            Spacer()
                            
                            Button {
                                numeraire.toggle()
                            } label: {
                                Image(R.image.swap_price)
                                    .tint(Color(R.color.text_tertiary))
                            }
                        }
                        
                        HStack {
                            Text(R.string.localizable.spot_trade_guide_you_receive())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            SpotTradingTokenView(
                                icon: .btc,
                                text: CurrencyFormatter.localizedString(
                                    from: payAmount / quote.price,
                                    format: .fiatMoneyPrice,
                                    sign: .never,
                                    symbol: .custom("BTC")
                                )
                            )
                        }
                    }
                }
                .padding(SpotTradingManual.cardInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(R.color.background()!))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(R.string.localizable.overview())
                        .modifier(ManualText(.heading))
                    Spacer()
                        .frame(height: 10)
                    
                    Text(R.string.localizable.spot_trade_guide_swap_desc())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.spot_trade_guide_use_cases())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.spot_trade_guide_swap_scenario_1(),
                        R.string.localizable.spot_trade_guide_swap_scenario_2(),
                        R.string.localizable.spot_trade_guide_swap_scenario_3(),
                    ])
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.spot_trade_guide_pricing())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.spot_trade_guide_swap_quote_1(),
                        R.string.localizable.spot_trade_guide_swap_quote_2(),
                    ])
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.risk_notice())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.spot_trade_guide_swap_risk(),
                    ])
                }
                .padding(SpotTradingManual.cardInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(R.color.background()!))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
        }
    }
    
}
