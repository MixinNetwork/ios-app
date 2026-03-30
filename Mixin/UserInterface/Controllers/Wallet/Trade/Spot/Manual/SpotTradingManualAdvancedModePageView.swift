import SwiftUI
import RswiftResources
import MixinServices

struct SpotTradingManualAdvancedModePageView: View {
    
    @EnvironmentObject private var quote: SpotTradingManual.Quote
    
    @State private var strategy: Strategy
    @State private var tradingModel: TradingModel
    @State private var numeraire: ExchangeRateQuote.Numeraire = .send
    
    init(price: Decimal) {
        let strategy: Strategy = .buying
        self.strategy = strategy
        self.tradingModel = .defaultModel(strategy: strategy, price: price)
    }
    
    var body: some View {
        ManualScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(R.string.localizable.example())
                        .modifier(ManualText(.heading))
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(R.string.localizable.trade_guide_strategy())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            SpotTradingSegmentControl(
                                segments: Strategy.allCases,
                                selection: $strategy
                            ) { strategy in
                                switch strategy {
                                case .buying:
                                    R.string.localizable.spot_trade_guide_limit_strategy_buy_low()
                                case .selling:
                                    R.string.localizable.spot_trade_guide_limit_strategy_sell_high()
                                }
                            }
                            .onChange(of: strategy) { newValue in
                                tradingModel = .defaultModel(strategy: newValue, price: quote.price)
                            }
                        }
                        
                        HStack {
                            Text(R.string.localizable.trade_guide_trading_pair())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            HStack(spacing: 4) {
                                SpotTradingTokenView(
                                    icon: tradingModel.sendToken.icon,
                                    text: tradingModel.sendToken.symbol
                                )
                                Text("→")
                                    .modifier(ManualText(.subheading(R.color.text()!)))
                                SpotTradingTokenView(
                                    icon: tradingModel.receiveToken.icon,
                                    text: tradingModel.receiveToken.symbol
                                )
                            }
                        }
                        
                        HStack {
                            Text(R.string.localizable.trade_guide_pay_amount())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            HStack(alignment: .center, spacing: 6) {
                                Button {
                                    tradingModel.updateSendAmount(by: -)
                                } label: {
                                    Image(R.image.stepper_decrease)
                                }
                                .disabled(!tradingModel.canUpdateSendAmount(by: -))
                                
                                Text(CurrencyFormatter.localizedString(
                                    from: tradingModel.sendAmount,
                                    format: .precision,
                                    sign: .never,
                                    symbol: .custom(tradingModel.sendToken.symbol)
                                ))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                                
                                Button {
                                    tradingModel.updateSendAmount(by: +)
                                } label: {
                                    Image(R.image.stepper_increase)
                                }
                            }
                        }
                        
                        HStack {
                            Text(R.string.localizable.trade_guide_limit_price())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            HStack(alignment: .center, spacing: 6) {
                                Button {
                                    tradingModel.updatePrice(by: -)
                                } label: {
                                    Image(R.image.stepper_decrease)
                                }
                                .disabled(!tradingModel.canUpdatePrice(by: -))
                                
                                Text(CurrencyFormatter.localizedString(
                                    from: tradingModel.price,
                                    format: .precision,
                                    sign: .never,
                                    symbol: .custom("USDT")
                                ))
                                .modifier(ManualText(.subheading(R.color.text()!), monospacedDigit: true))
                                
                                Button {
                                    tradingModel.updatePrice(by: +)
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
                                icon: tradingModel.receiveToken.icon,
                                text: CurrencyFormatter.localizedString(
                                    from: tradingModel.receiveAmount,
                                    format: .precision,
                                    sign: .never,
                                    symbol: .custom(tradingModel.receiveToken.symbol)
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
                    
                    Text(R.string.localizable.spot_trade_guide_limit_desc())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.spot_trade_guide_use_cases())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.spot_trade_guide_limit_scenario_1(),
                        R.string.localizable.spot_trade_guide_limit_scenario_2(),
                        R.string.localizable.spot_trade_guide_limit_scenario_3(),
                    ])
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.risk_notice())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.spot_trade_guide_limit_risk(),
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

extension SpotTradingManualAdvancedModePageView {
    
    private enum Strategy: CaseIterable {
        case buying
        case selling
    }
    
    private struct TradingModel {
        
        struct Token: Equatable {
            
            let icon: SpotTradingTokenView.Icon
            let symbol: String
            
            static let btc = Token(icon: .btc, symbol: "BTC")
            static let usdt = Token(icon: .usdt, symbol: "USDT")
            
            static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.icon == rhs.icon
            }
            
        }
        
        let sendToken: Token
        let receiveToken: Token
        
        let sendAmountStep: Decimal
        let priceStep: Decimal = 1000
        
        private(set) var sendAmount: Decimal
        private(set) var price: Decimal
        
        var receiveAmount: Decimal {
            switch (sendToken, receiveToken) {
            case (.usdt, .btc):
                sendAmount / price
            case (.btc, .usdt):
                sendAmount * price
            default:
                -1
            }
        }
        
        static func defaultModel(strategy: Strategy, price: Decimal) -> TradingModel {
            switch strategy {
            case .buying:
                TradingModel(
                    sendToken: .usdt,
                    receiveToken: .btc,
                    sendAmountStep: 100,
                    sendAmount: 1000,
                    price: roundToPowerOf10(value: price, rounding: .down),
                )
            case .selling:
                TradingModel(
                    sendToken: .btc,
                    receiveToken: .usdt,
                    sendAmountStep: 0.1,
                    sendAmount: 1,
                    price: roundToPowerOf10(value: price, rounding: .up),
                )
            }
        }
        
        private static func roundToPowerOf10(
            value: Decimal,
            rounding: NSDecimalNumber.RoundingMode
        ) -> Decimal {
            guard value != 0 else {
                return 0
            }
            let isNegative = value < 0
            let absoluteValue = isNegative ? -value : value
            let doubleValue = NSDecimalNumber(decimal: absoluteValue).doubleValue
            let power = Int(floor(log10(doubleValue)))
            let basePower = pow(Decimal(10), power)
            var quotient = absoluteValue / basePower
            var roundedQuotient = Decimal()
            NSDecimalRound(&roundedQuotient, &quotient, 0, rounding)
            let result = roundedQuotient * basePower
            return isNegative ? -result : result
        }
        
        func canUpdateSendAmount(by op: (Decimal, Decimal) -> Decimal) -> Bool {
            let result = op(sendAmount, sendAmountStep)
            return result > sendAmountStep
        }
        
        mutating func updateSendAmount(by op: (Decimal, Decimal) -> Decimal) {
            sendAmount = op(sendAmount, sendAmountStep)
        }
        
        func canUpdatePrice(by op: (Decimal, Decimal) -> Decimal) -> Bool {
            let result = op(price, priceStep)
            return result > priceStep
        }
        
        mutating func updatePrice(by op: (Decimal, Decimal) -> Decimal) {
            price = op(price, priceStep)
        }
        
    }
    
}
