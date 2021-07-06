import UIKit

class HomeAppsSnapshotView: UIView {
    
    var iconView: UIView
    var nameView: UIView?
    
    required init(frame: CGRect, iconView: UIView, nameView: UIView? = nil) {
        self.iconView = iconView
        self.nameView = nameView
        super.init(frame: frame)
        addSubview(iconView)
        if let nameView = nameView {
            addSubview(nameView)
        }
        var shadowFrame = iconView.frame
        shadowFrame.origin.y += 5
        let shadowPath = UIBezierPath(ovalIn: shadowFrame)
        iconView.layer.shadowColor = R.color.icon_shadow()!.cgColor
        iconView.layer.shadowOpacity = 0.4
        iconView.layer.shadowRadius = 6
        iconView.layer.shadowPath = shadowPath.cgPath
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
