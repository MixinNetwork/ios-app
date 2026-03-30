import SwiftUI
import RswiftResources

struct SpotTradingTokenView: View {
    
    enum Icon {
        case usdt
        case btc
    }
    
    private let icon: RswiftResources.ImageResource
    private let text: String
    
    init(icon: Icon, text: String) {
        self.icon = switch icon {
        case .usdt:
            R.image.usdt
        case .btc:
            R.image.bitcoin_chain
        }
        self.text = text
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(icon)
                .frame(width: 18, height: 18)
            Text(text)
                .modifier(ManualText(.subheading(R.color.text()!)))
        }
    }
    
}
