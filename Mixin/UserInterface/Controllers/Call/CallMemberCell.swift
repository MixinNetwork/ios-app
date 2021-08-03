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
    
    private let speakingIndicatorLayer: CALayer = {
        let size = CGSize(width: 74, height: 74)
        let path = UIBezierPath(arcCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                                radius: size.width / 2,
                                startAngle: 0,
                                endAngle: 2 * .pi,
                                clockwise: true)
        let layer = CAShapeLayer()
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor(displayP3RgbValue: 0x50BD5C).cgColor
        layer.lineWidth = 2
        layer.path = path.cgPath
        layer.isHidden = true
        return layer
    }()
    
    var hasBiggerLayout = true {
        didSet {
            let constant = hasBiggerLayout ? Layout.bigger : Layout.normal
            labelTopConstraint.constant = constant.labelTopMargin
            avatarWrapperWidthConstraint.constant = constant.avatarWrapperWidth
        }
    }
    
    var isSpeaking = false {
        didSet {
            speakingIndicatorLayer.isHidden = !isSpeaking
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.font = Self.labelFont
        label.adjustsFontForContentSizeCategory = true
        layer.insertSublayer(speakingIndicatorLayer, at: 0)
    }
    
    override func layoutSubviews() {
        UIView.performWithoutAnimation {
            super.layoutSubviews()
            avatarWrapperView.layer.cornerRadius = avatarWrapperView.frame.width / 2
            speakingIndicatorLayer.position = avatarWrapperView.center
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
        isSpeaking = false
    }
    
}
