import UIKit

final class HomeAppsSnapshotView: UIView {
    
    let iconView: UIView
    var source: HomeAppsMode = .regular
    
    init(frame: CGRect, iconView: UIView) {
        self.iconView = iconView
        super.init(frame: frame)
        addSubview(iconView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
