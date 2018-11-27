import UIKit

class LegacySearchBoxView: UIView, XibDesignable, SearchBox {
    
    @IBOutlet weak var separatorLineView: UIView!
    @IBOutlet weak var textField: UITextField!
    
    let height: CGFloat = 44
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
}
