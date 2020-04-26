import UIKit

class SettingsHeaderFooterView: UITableViewHeaderFooterView {
    
    class var labelInsets: UIEdgeInsets {
        .zero
    }
    
    let label = UILabel()
    
    var text: String? {
        get {
            label.text
        }
        set {
            if let text = newValue, !text.isEmpty {
                let attributedText = NSAttributedString(string: text, attributes: textAttributes)
                label.attributedText = attributedText
            } else {
                label.text = nil
            }
        }
    }
    
    var textAttributes: [NSAttributedString.Key: Any] {
        [:]
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
        label.adjustsFontForContentSizeCategory = true
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(Self.labelInsets.top)
            make.leading.equalToSuperview().offset(Self.labelInsets.left)
            make.trailing.equalToSuperview().offset(-Self.labelInsets.right)
        }
    }
    
}
