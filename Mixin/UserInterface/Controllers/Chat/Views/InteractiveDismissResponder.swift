import UIKit

class InteractiveDismissResponder: UIView {
    
    var height: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    convenience init(height: CGFloat) {
        self.init(frame: .zero)
        self.height = height
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.layoutFittingExpandedSize.width, height: height)
    }
    
    private func prepare() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
}
