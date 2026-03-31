import Foundation
import SwiftUI
import MixinServices

struct SpotTradingManual {
    
    final class Quote: ObservableObject {
        
        @Published var progress: CGFloat
        @Published var price: Decimal
        
        init() {
            self.progress = 0
            if let price = TokenDAO.shared.usdPrice(assetID: AssetID.btc),
               let decimalPrice = Decimal(string: price, locale: .enUSPOSIX)
            {
                self.price = decimalPrice
            } else {
                self.price = 71000
            }
        }
        
    }
    
    struct CircularProgressView: View {
        
        @Binding var progress: CGFloat
        
        private let lineWidth: CGFloat = 2
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color(R.color.button_background_disabled), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(R.color.icon_tint),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
    }
    
    static let cardInsets = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
    
}
