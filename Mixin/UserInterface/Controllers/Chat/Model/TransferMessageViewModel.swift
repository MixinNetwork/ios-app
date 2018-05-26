import UIKit

class TransferMessageViewModel: CardMessageViewModel {
    
    let snapshotAmount: String?
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        snapshotAmount = message.snapshotAmount?.formatSimpleBalance()
        super.init(message: message, style: style, fits: layoutWidth)
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        timeFrame.size.width = backgroundImageFrame.width - DetailInfoMessageViewModel.margin.leading
    }
    
}
