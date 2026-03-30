import SwiftUI
import RswiftResources

struct SpotTradingManualIntroductionPageView: View {
    
    var body: some View {
        ManualScrollView {
            VStack {
                VStack(alignment: .leading) {
                    Text(R.string.localizable.overview())
                        .modifier(ManualText(.heading))
                    Spacer()
                        .frame(height: 10)
                    
                    Text(R.string.localizable.spot_trade_guide_overview_desc())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.product_features())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    
                    BulletinText([
                        R.string.localizable.spot_trade_guide_feature_1(),
                        R.string.localizable.spot_trade_guide_feature_2(),
                    ])
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.spot_trade_guide_fees())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    
                    BulletinText([
                        R.string.localizable.spot_trade_guide_note_1(),
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
