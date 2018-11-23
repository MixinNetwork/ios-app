import UIKit

protocol SearchBoxView {
    var textField: UITextField! { get }
    var separatorLineView: UIView! { get }
    var height: CGFloat { get }
}

class SmallerSearchBoxView: UIView, XibDesignable, SearchBoxView {
    
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
