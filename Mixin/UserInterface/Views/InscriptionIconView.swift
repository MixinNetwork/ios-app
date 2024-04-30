import UIKit
import MixinServices

class InscriptionIconView: UIView {
    
    let iconImageView = UIImageView()
    let shadowOffset: CGFloat = 5
    
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
    }
    
    func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }
    
    func setIcon(inscription: InscriptionItem) {
        if inscription.contentType.starts(with: "image/") && !inscription.contentUrl.isEmpty {
            iconImageView.sd_setImage(with: URL(string: inscription.contentUrl),
                                      placeholderImage: nil,
                                      context: assetIconContext)
        } else {
            // FIX ME placeholder image
        }
    }
    
    private func prepare() {
        backgroundColor = .clear
        iconImageView.layer.masksToBounds = true
        addSubview(iconImageView)
        layer.shadowColor = R.color.icon_shadow()!.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
        iconImageView.backgroundColor = R.color.background_secondary()
    }
    
}
