import UIKit

class TransferMessageViewModel: CardMessageViewModel {
    
    override func didSetStyle() {
        super.didSetStyle()
        timeFrame.size.width = backgroundImageFrame.width - DetailInfoMessageViewModel.margin.leading
    }
    
}
