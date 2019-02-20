import UIKit

class WalletFooterView: UITableViewHeaderFooterView {
    
    let shadowView = SeparatorShadowView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addSubview(shadowView)
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        addSubview(shadowView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.frame = bounds
    }
    
}
