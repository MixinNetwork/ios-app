import UIKit

class ChainSubscriptedAssetIconView: UIView {
    
    @IBInspectable var chainIconWidth: CGFloat = 10
    
    let iconImageView = UIImageView()
    let chainImageView = UIImageView()
    
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
        chainImageView.frame.size = CGSize(width: chainIconWidth, height: chainIconWidth)
        let radius = bounds.width / 2
        let delta = radius / sqrt(2)
        chainImageView.center = CGPoint(x: radius - delta, y: radius + delta)
        iconImageView.frame = bounds
        iconImageView.layer.cornerRadius = radius
    }
    
    func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
        chainImageView.image = nil
    }
    
    func setIcon(asset: AssetItem) {
        iconImageView.sd_setImage(with: URL(string: asset.iconUrl), completed: nil)
        if let str = asset.chainIconUrl, let url = URL(string: str) {
            chainImageView.sd_setImage(with: url, completed: nil)
            chainImageView.isHidden = false
        } else {
            chainImageView.isHidden = true
        }
    }
    
    private func prepare() {
        iconImageView.clipsToBounds = true
        addSubview(iconImageView)
        addSubview(chainImageView)
        chainImageView.alpha = 0.7
        setNeedsLayout()
        layoutIfNeeded()
    }
    
}
