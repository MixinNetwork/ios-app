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
    
    var status: GroupCallMembersDataSource.Member.Status? {
        didSet {
            guard status != oldValue else {
                return
            }
            switch status {
            case .isSpeaking:
                statusIndicatorLayer.strokeColor = UIColor(displayP3RgbValue: 0x50BD5C).cgColor
                statusIndicatorLayer.opacity = 1
            case .isTrackDisabled:
                statusIndicatorLayer.strokeColor = UIColor.mixinRed.cgColor
                statusIndicatorLayer.opacity = 1
            case .none:
                statusIndicatorLayer.opacity = 0
            }
        }
    }
    
    private let statusIndicatorLayer: CAShapeLayer = {
        let size = CGSize(width: 74, height: 74)
        let path = UIBezierPath(arcCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                                radius: size.width / 2,
                                startAngle: 0,
                                endAngle: 2 * .pi,
                                clockwise: true)
        let layer = CAShapeLayer()
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2
        layer.path = path.cgPath
        layer.opacity = 0
        return layer
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.font = Self.labelFont
        label.adjustsFontForContentSizeCategory = true
        avatarWrapperView.layer.insertSublayer(statusIndicatorLayer, at: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        avatarWrapperView.layer.cornerRadius = avatarWrapperView.frame.width / 2
        connectingView.layer.cornerRadius = connectingView.frame.width / 2
        statusIndicatorLayer.position = CGPoint(x: avatarWrapperView.bounds.midX,
                                                y: avatarWrapperView.bounds.midY)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
        status = nil
    }
    
}
