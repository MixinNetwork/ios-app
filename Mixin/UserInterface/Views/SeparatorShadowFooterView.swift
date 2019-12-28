import UIKit

class SeparatorShadowFooterView: UITableViewHeaderFooterView {
    
    let shadowView = SeparatorShadowView()
    let labelInset = UIEdgeInsets(top: 12, left: 20, bottom: 16, right: 20)
    
    lazy var label: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .accessoryText
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        contentView.addSubview(label)
        return label
    }()
    
    private var cachedSize: CGSize?
    
    var text: String? {
        get {
            return label.text
        }
        set {
            label.text = newValue
            label.isHidden = newValue == nil
            cachedSize = nil
        }
    }
    
    var attributedText: NSAttributedString? {
        get {
            return label.attributedText
        }
        set {
            label.attributedText = newValue
            label.isHidden = newValue == nil
            cachedSize = nil
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutShadowViewAndLabel()
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
    
    func layoutShadowViewAndLabel() {
        shadowView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        if text != nil {
            label.frame = CGRect(x: labelInset.left,
                                 y: labelInset.top,
                                 width: bounds.width - labelInset.horizontal,
                                 height: bounds.height - labelInset.vertical)
        }
    }
    
    func prepare() {
        contentView.addSubview(shadowView)
        clipsToBounds = true
        backgroundView = UIView(frame: bounds)
        backgroundView?.backgroundColor = .secondaryBackground
    }
    
}
