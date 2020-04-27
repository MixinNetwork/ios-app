import UIKit

class SettingsHeaderFooterView: UITableViewHeaderFooterView {
    
    class var labelInsets: UIEdgeInsets {
        .zero
    }
    
    class var textColor: UIColor {
        .text
    }
    
    class var textStyle: UIFont.TextStyle {
        .caption1
    }
    
    class var attributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: textColor,
         .font: UIFont.preferredFont(forTextStyle: textStyle)]
    }
    
    let label = UILabel()
    
    var text: String? {
        get {
            label.text
        }
        set {
            label.text = newValue
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        text = nil
    }
    
    func prepare() {
        clipsToBounds = true
        let background = UIView(frame: bounds)
        background.backgroundColor = .clear
        backgroundView = background
        label.backgroundColor = .clear
        label.numberOfLines = 0
        label.textColor = Self.textColor
        label.font = .preferredFont(forTextStyle: Self.textStyle)
        label.adjustsFontForContentSizeCategory = true
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(Self.labelInsets.top)
            make.leading.equalToSuperview().offset(Self.labelInsets.left)
            make.trailing.equalToSuperview().offset(-Self.labelInsets.right)
            make.bottom.equalToSuperview().offset(-Self.labelInsets.bottom).priority(.high)
        }
    }
    
}
