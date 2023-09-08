import UIKit

class ComboBoxView: UIView, XibDesignable {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var accessoryImageView: UIImageView!
    @IBOutlet weak var button: UIButton!
    
    // Protocol extensions are not polymorphic. Declare this variable
    // explicitly for subclasses. See `XibDesignable`
    let nibName = R.nib.comboBoxView.name
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }
    
    func insertIconView(_ iconView: UIView) {
        contentStackView.insertArrangedSubview(iconView, at: 0)
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
    }
    
}
