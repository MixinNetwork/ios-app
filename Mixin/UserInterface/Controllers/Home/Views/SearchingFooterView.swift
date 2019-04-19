import UIKit

class SearchingFooterView: UIView {
    
    let indicator = ActivityIndicatorView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        indicator.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }
    
    private func prepare() {
        indicator.bounds.size = indicator.intrinsicContentSize
        addSubview(indicator)
    }
    
}
