import UIKit

class CallMemberCell: UICollectionViewCell {
    
    enum Layout {
        
        struct Constant {
            let labelTopMargin: CGFloat
            let avatarWrapperWidth: CGFloat
        }
        
        static let normal = Constant(labelTopMargin: 8, avatarWrapperWidth: 64)
        static let bigger = Constant(labelTopMargin: 14, avatarWrapperWidth: 96)
        
    }
    
    static let labelFont = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
    
    @IBOutlet weak var avatarWrapperView: UIView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var connectingView: GroupCallMemberConnectingView!
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var avatarWrapperWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelTopConstraint: NSLayoutConstraint!
    
    var hasBiggerLayout = true {
        didSet {
            let constant = hasBiggerLayout ? Layout.bigger : Layout.normal
            labelTopConstraint.constant = constant.labelTopMargin
            avatarWrapperWidthConstraint.constant = constant.avatarWrapperWidth
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.font = Self.labelFont
        label.adjustsFontForContentSizeCategory = true
    }
    
    override func layoutSubviews() {
        UIView.performWithoutAnimation {
            super.layoutSubviews()
            avatarWrapperView.layer.cornerRadius = avatarWrapperView.frame.width / 2
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
    }
    
}
