import UIKit
import MixinServices

class TransferMessageViewModel: CardMessageViewModel, TitledCardContentWidthCalculable {
    
    let snapshotAmount: String?
    
    override init(message: MessageItem) {
        snapshotAmount = CurrencyFormatter.localizedString(from: message.snapshotAmount, format: .precision, sign: .whenNegative)
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: Style) {
        updateContentWidth(title: snapshotAmount,
                           titleFont: MessageFontSet.transferAmount.scaled,
                           subtitle: message.assetSymbol,
                           subtitleFont: MessageFontSet.cardSubtitle.scaled)
        super.layout(width: width, style: style)
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
    }
    
}
