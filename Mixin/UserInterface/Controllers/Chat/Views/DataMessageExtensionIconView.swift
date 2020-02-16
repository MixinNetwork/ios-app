import UIKit

class DataMessageExtensionIconView: UIView, XibDesignable {
    
    @IBOutlet weak var extensionNameWrapperView: UIView!
    @IBOutlet weak var extensionNameLabel: UILabel!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }
    
}
