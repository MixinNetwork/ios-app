import UIKit

class SearchFooterView: UITableViewHeaderFooterView {
    
    let shadowView = SeparatorShadowView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        contentView.addSubview(shadowView)
        shadowView.clipsToBounds = true
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.addSubview(shadowView)
        shadowView.clipsToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let shadowViewHeight: CGFloat = 10
        shadowView.frame = CGRect(x: 0,
                                  y: bounds.height - shadowViewHeight,
                                  width: bounds.width,
                                  height: shadowViewHeight)
    }
    
}
