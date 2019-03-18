import UIKit

class SeparatorShadowFooterView: UITableViewHeaderFooterView {
    
    private let shadowHeight: CGFloat = 10
    private let labelInset = UIEdgeInsets(top: 2, left: 20, bottom: 16, right: 20)
    private let shadowView = SeparatorShadowView()
    
    private lazy var label: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .accessoryText
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 12)
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
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        contentView.addSubview(shadowView)
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.addSubview(shadowView)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        text = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: shadowHeight)
        if text != nil {
            label.frame = CGRect(x: labelInset.left,
                                 y: shadowHeight + labelInset.top,
                                 width: bounds.width - labelInset.horizontal,
                                 height: bounds.height - shadowHeight - labelInset.vertical)
        }
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        if text == nil {
            return CGSize(width: targetSize.width, height: shadowHeight)
        } else {
            let layoutWidth = targetSize.width > 0 ? targetSize.width : 375
            let labelLayoutSize = CGSize(width: layoutWidth - labelInset.horizontal,
                                         height: UIView.layoutFittingExpandedSize.height)
            if let cachedSize = cachedSize, cachedSize.width == targetSize.width {
                return cachedSize
            } else {
                let height = shadowHeight
                    + labelInset.top
                    + label.sizeThatFits(labelLayoutSize).height
                    + labelInset.bottom
                let size = CGSize(width: targetSize.width, height: ceil(height))
                cachedSize = size
                return size
            }
        }
    }
    
}
