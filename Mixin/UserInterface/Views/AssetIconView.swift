import UIKit
import MixinServices

class AssetIconView: UIView {
    
    @IBInspectable var chainIconWidth: CGFloat = 10
    @IBInspectable var chainIconOutlineWidth: CGFloat = 2
    
    let iconImageView = UIImageView()
    let chainBackgroundView = WhiteBackgroundedView()
    let chainImageView = UIImageView()
    let shadowOffset: CGFloat = 5
    
    private var chainIconIsHidden = false {
        didSet {
            chainBackgroundView.isHidden = chainIconIsHidden
            chainImageView.isHidden = chainIconIsHidden
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        iconImageView.frame = bounds
        iconImageView.layer.cornerRadius = iconImageView.bounds.width / 2
        let chainBackgroundDiameter = chainIconWidth + chainIconOutlineWidth
        chainBackgroundView.frame = CGRect(x: 0,
                                           y: bounds.height - chainBackgroundDiameter,
                                           width: chainBackgroundDiameter,
                                           height: chainBackgroundDiameter)
        chainBackgroundView.layer.cornerRadius = chainBackgroundDiameter / 2
        chainImageView.bounds = CGRect(x: 0, y: 0, width: chainIconWidth, height: chainIconWidth)
        chainImageView.center = chainBackgroundView.center
        chainImageView.layer.cornerRadius = chainImageView.bounds.width / 2
        updateShadowPath(chainIconIsHidden: chainIconIsHidden)
    }
    
    func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
        chainImageView.image = nil
    }
    
    func setIcon(asset: AssetItem) {
        let url = URL(string: asset.iconUrl)
        iconImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
        let shouldHideChainIcon: Bool
        if let str = asset.chainIconUrl, let url = URL(string: str) {
            chainImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            shouldHideChainIcon = false
        } else {
            shouldHideChainIcon = true
        }
        if chainIconIsHidden != shouldHideChainIcon {
            updateShadowPath(chainIconIsHidden: shouldHideChainIcon)
        }
        chainIconIsHidden = shouldHideChainIcon
    }
    
    private func prepare() {
        backgroundColor = .clear
        iconImageView.clipsToBounds = true
        chainBackgroundView.clipsToBounds = true
        chainImageView.clipsToBounds = true
        addSubview(iconImageView)
        addSubview(chainBackgroundView)
        addSubview(chainImageView)
        updateShadowPath(chainIconIsHidden: false)
        layer.shadowColor = R.color.icon_shadow()!.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
    }
    
    private func updateShadowPath(chainIconIsHidden: Bool) {
        let iconFrame = CGRect(x: 0,
                               y: iconImageView.frame.origin.y + shadowOffset,
                               width: iconImageView.frame.width,
                               height: iconImageView.frame.height)
        let shadowPath = UIBezierPath(ovalIn: iconFrame)
        if !chainIconIsHidden {
            let chainFrame = CGRect(x: 0,
                                    y: chainBackgroundView.frame.origin.y + shadowOffset,
                                    width: chainBackgroundView.frame.width,
                                    height: chainBackgroundView.frame.height)
            let chainPath = UIBezierPath(ovalIn: chainFrame)
            shadowPath.append(chainPath)
        }
        layer.shadowPath = shadowPath.cgPath
    }
    
}
