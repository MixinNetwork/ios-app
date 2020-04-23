import UIKit

class SettingsHeaderFooterView: UITableViewHeaderFooterView {
    
    let labelInset = UIEdgeInsets(top: 12, left: 20, bottom: 16, right: 20)
    let label = UILabel()
    
    var text: String? {
        get {
            label.text
        }
        set {
            label.text = newValue
            label.isHidden = newValue == nil
            cachedSize = nil
        }
    }
    
    var attributedText: NSAttributedString? {
        get {
            label.attributedText
        }
        set {
            label.attributedText = newValue
            label.isHidden = newValue == nil
            cachedSize = nil
        }
    }
    
    private var cachedSize: CGSize?
    
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if text != nil {
            label.frame = CGRect(x: labelInset.left,
                                 y: labelInset.top,
                                 width: bounds.width - labelInset.horizontal,
                                 height: bounds.height - labelInset.vertical)
        }
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        if text == nil {
            return CGSize(width: targetSize.width, height: 10)
        } else {
            let layoutWidth = targetSize.width > 0 ? targetSize.width : 375
            let labelLayoutSize = CGSize(width: layoutWidth - labelInset.horizontal,
                                         height: UIView.layoutFittingExpandedSize.height)
            if let cachedSize = cachedSize, cachedSize.width == targetSize.width {
                return cachedSize
            } else {
                let height = labelInset.vertical + label.sizeThatFits(labelLayoutSize).height
                let size = CGSize(width: targetSize.width, height: ceil(height))
                cachedSize = size
                return size
            }
        }
    }
    
    func prepare() {
        clipsToBounds = true
        let background = UIView(frame: bounds)
        background.backgroundColor = .clear
        backgroundView = background
        contentView.addSubview(label)
    }
    
}
