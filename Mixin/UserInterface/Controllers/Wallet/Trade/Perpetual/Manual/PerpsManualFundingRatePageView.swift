import SwiftUI
import MixinServices

struct PerpsManualFundingRatePageView: View {
    
    private enum FundingRate: CaseIterable {
        case positive
        case negative
    }
    
    private let product = "BTC - USD"
    
    @State private var fundingRate: FundingRate = .positive
    
    private var longRate: Decimal {
        -rate(fundingRate: fundingRate)
    }
    
    private var shortRate: Decimal {
        rate(fundingRate: fundingRate)
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
                            Image(R.image.bitcoin_chain)
                                .frame(width: 18, height: 18)
                            Spacer()
                                .frame(width: 4)
                            Text(product)
                                .modifier(ManualText(.subheading(R.color.text()!)))
                        }
                        HStack {
                            Text(R.string.localizable.funding_rate())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            SpotTradingSegmentControl(
                                segments: FundingRate.allCases,
                                selection: $fundingRate
                            ) { fundingRate in
                                PercentageFormatter.string(
                                    from: rate(fundingRate: fundingRate),
                                    format: .precision,
                                    sign: .always
                                )
                            } selectionBackgroundColor: { fundingRate in
                                switch fundingRate {
                                case .positive:
                                    MarketColor.rising.uiColor
                                case .negative:
                                    MarketColor.falling.uiColor
                                }
                            }
                        }
                        HStack {
                            Text(R.string.localizable.perps_funding_frequency())
                                .modifier(ManualText(.caption2))
                            Spacer()
                            Text(R.string.localizable.perps_funding_frequency_value())
                                .modifier(ManualText(.subheading(R.color.text()!)))
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        Text(R.string.localizable.long())
                            .modifier(ManualText(.caption1))
                        HStack {
                            if longRate > 0 {
                                Text(R.string.localizable.perps_receive())
                                    .modifier(ManualText(.caption2))
                            } else {
                                Text(R.string.localizable.pay())
                                    .modifier(ManualText(.caption2))
                            }
                            Spacer()
                            Text(
                                PercentageFormatter.string(
                                    from: longRate,
                                    format: .precision,
                                    sign: .always
                                )
                            )
                            .modifier(
                                ManualText(
                                    .subheading(longRate > 0 ? MarketColor.rising.uiColor : MarketColor.falling.uiColor),
                                    monospacedDigit: false
                                )
                            )
                        }
                        
                        Rectangle()
                            .fill(Color(R.color.background_quaternary()!))
                            .frame(height: 1)
                        
                        Text(R.string.localizable.short())
                            .modifier(ManualText(.caption1))
                        HStack {
                            if shortRate > 0 {
                                Text(R.string.localizable.perps_receive())
                                    .modifier(ManualText(.caption2))
                            } else {
                                Text(R.string.localizable.pay())
                                    .modifier(ManualText(.caption2))
                            }
                            Spacer()
                            Text(
                                PercentageFormatter.string(
                                    from: shortRate,
                                    format: .precision,
                                    sign: .always
                                )
                            )
                            .modifier(
                                ManualText(
                                    .subheading(shortRate > 0 ? MarketColor.rising.uiColor : MarketColor.falling.uiColor),
                                    monospacedDigit: false
                                )
                            )
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
                    Text(R.string.localizable.perps_funding_rate_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.perps_funding_rate_purpose())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    BulletinText([
                        R.string.localizable.perps_funding_rate_key_point_1(),
                        R.string.localizable.perps_funding_rate_key_point_2(),
                        R.string.localizable.perps_funding_rate_key_point_3(),
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
    
    private func rate(fundingRate: FundingRate) -> Decimal {
        switch fundingRate {
        case .positive:
            0.0001
        case .negative:
            -0.0001
        }
    }
    
}
