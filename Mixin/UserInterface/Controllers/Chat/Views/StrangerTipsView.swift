import UIKit

class StrangerTipsView: UIView, XibDesignable {
    
    static let height: CGFloat = 110
    
    @IBOutlet weak var blockButton: StateResponsiveButton!
    @IBOutlet weak var addContactButton: StateResponsiveButton!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
}
