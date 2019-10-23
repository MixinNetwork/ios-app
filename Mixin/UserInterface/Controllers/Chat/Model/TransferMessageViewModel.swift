import UIKit

class TransferMessageViewModel: CardMessageViewModel {
    
    let snapshotAmount: String?
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        snapshotAmount = CurrencyFormatter.localizedString(from: message.snapshotAmount, format: .precision, sign: .whenNegative)
        super.init(message: message, style: style, fits: layoutWidth)
    }
    
    override func layout() {
        super.layout()
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
    }
    
}
