import UIKit

class InfiniteTopView: UIView {
    
    let topFillerHeight: CGFloat = 900
    let topFillerView = UIView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    private func prepare() {
        topFillerView.backgroundColor = .background
        topFillerView.frame = CGRect(x: 0, y: -topFillerHeight, width: bounds.width, height: topFillerHeight)
        topFillerView.autoresizingMask = [.flexibleWidth]
        insertSubview(topFillerView, at: 0)
    }
    
}
