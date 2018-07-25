import UIKit

class TransferMessageViewModel: CardMessageViewModel {
    
    let snapshotAmount: String?
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        snapshotAmount = CurrencyFormatter.localizedString(from: message.snapshotAmount, format: .pretty, sign: .whenNegative)
        super.init(message: message, style: style, fits: layoutWidth)
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
    }
    
}
