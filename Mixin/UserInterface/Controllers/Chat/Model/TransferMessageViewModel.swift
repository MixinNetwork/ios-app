import UIKit
import MixinServices

class TransferMessageViewModel: CardMessageViewModel, TitledCardContentWidthCalculable {
    
    static let amountFontSet = MessageFontSet(style: .title3)
    static let symbolFontSet = MessageFontSet(size: 14, weight: .regular)
    
    let snapshotAmount: String?
    
    override init(message: MessageItem) {
        snapshotAmount = CurrencyFormatter.localizedString(from: message.snapshotAmount, format: .precision, sign: .whenNegative)
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: Style) {
        updateContentWidth(title: snapshotAmount,
                           titleFont: Self.amountFontSet.scaled,
                           subtitle: message.assetSymbol,
                           subtitleFont: Self.symbolFontSet.scaled)
        super.layout(width: width, style: style)
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
    }
    
}
