import UIKit
import MixinServices

class TransferMessageViewModel: CardMessageViewModel {
    
    let snapshotAmount: String?
    
    override init(message: MessageItem) {
        snapshotAmount = CurrencyFormatter.localizedString(from: message.snapshotAmount, format: .precision, sign: .whenNegative)
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
    }
    
}
