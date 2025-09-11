import UIKit

final class HomeNavigationTitleView: UIView, XibDesignable {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var settingButton: UIButton!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
    }
    
}
