import UIKit
import MixinServices

class TransferMessageViewModel: CardMessageViewModel {
    
    static let amountFont = UIFont.preferredFont(forTextStyle: .title3)
    static let symbolFont = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
    
    let snapshotAmount: String?
    
    override var contentWidth: CGFloat {
        calculatedContentWidth
    }
    
    private var calculatedContentWidth: CGFloat = 0
    
    override init(message: MessageItem) {
        snapshotAmount = CurrencyFormatter.localizedString(from: message.snapshotAmount, format: .precision, sign: .whenNegative)
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let amountWidth = ((snapshotAmount ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: Self.amountFont])
            .width
        let symbolWidth = ((message.assetSymbol ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: Self.symbolFont])
            .width
        calculatedContentWidth = ceil(max(amountWidth, symbolWidth))
            + 40 + 12 + receivedLeadingMargin + receivedTrailingMargin
        calculatedContentWidth = max(160, min(260, calculatedContentWidth))
        super.layout(width: width, style: style)
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
    }
    
}
