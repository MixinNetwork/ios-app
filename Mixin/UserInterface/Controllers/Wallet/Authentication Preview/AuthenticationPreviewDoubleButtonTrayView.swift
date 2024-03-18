import UIKit

final class AuthenticationPreviewDoubleButtonTrayView: UIView {
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: BusyButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        rightButton.busyIndicator.tintColor = .white
    }
    
}
