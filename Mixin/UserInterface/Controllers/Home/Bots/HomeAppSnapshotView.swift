import UIKit

class HomeAppSnapshotView: UIView {
    
    var iconView: UIView
    var nameView: UIView
    
    required init(frame: CGRect, iconView: UIView, nameView: UIView) {
        self.iconView = iconView
        self.nameView = nameView
        super.init(frame: frame)
        addSubview(iconView)
        addSubview(nameView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
