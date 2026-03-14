import SwiftUI
import RswiftResources

struct PerpsManualIntroductionPageView: View {
    
    var body: some View {
        ManualScrollView {
            VStack {
                VStack(alignment: .leading) {
                    Text(R.string.localizable.overview())
                        .modifier(ManualText(.heading))
                    Spacer()
                        .frame(height: 10)
                    
                    Text(R.string.localizable.perps_intro_overview())
                        .modifier(ManualText(.body))
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.product_features())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    
                    BulletinText([
                        R.string.localizable.product_features_1(),
                        R.string.localizable.product_features_2(),
                        R.string.localizable.product_features_3(200),
                        R.string.localizable.product_features_4(),
                        R.string.localizable.product_features_5(),
                    ])
                    Spacer()
                        .frame(height: 12)
                    
                    Text(R.string.localizable.risk_notice())
                        .modifier(ManualText(.subheading(R.color.text()!)))
                    Spacer()
                        .frame(height: 4)
                    
                    BulletinText([
                        R.string.localizable.perps_intro_risk_notice_1(),
                        R.string.localizable.perps_intro_risk_notice_2(),
                        R.string.localizable.perps_intro_risk_notice_3(),
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
