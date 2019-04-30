import UIKit

class AvatarShadowIconView: UIView {

    @IBInspectable
    var titleFontSize: CGFloat = 17 {
        didSet {
            titleLabel?.font = .systemFont(ofSize: titleFontSize)
        }
    }
    var titleLabel: UILabel!

    let iconImageView = UIImageView()
    let shadowOffset: CGFloat = 5
    let shadowColor = UIColor(rgbValue: 0x888888).cgColor

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
        layoutIconImageView()
        iconImageView.layer.cornerRadius = iconImageView.bounds.width / 2
        updateShadowPath()
    }
    
    func layoutIconImageView() {
        iconImageView.frame = bounds
    }
    
    func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }

    func setGroupImage(with iconUrl: String) {
        titleLabel.text = nil
        iconImageView.backgroundColor = .clear

        if !iconUrl.isEmpty {
            iconImageView.sd_setImage(with: MixinFile.groupIconsUrl.appendingPathComponent(iconUrl))
        } else {
            iconImageView.image = #imageLiteral(resourceName: "ic_conversation_group")
        }
    }

    func setImage(with url: String, userId: String, name: String, placeholder: Bool = true) {
        if let url = URL(string: url) {
            titleLabel.text = nil
            iconImageView.backgroundColor = .clear
            let placeholder = placeholder ? #imageLiteral(resourceName: "ic_place_holder") : nil
            iconImageView.sd_setImage(with: url, placeholderImage: placeholder, options: .lowPriority)
        } else {
            iconImageView.image = UIImage(named: "color\(userId.positiveHashCode() % 24 + 1)")
            iconImageView.backgroundColor = .clear
            if let firstLetter = name.first {
                titleLabel.text = String([firstLetter]).uppercased()
            } else {
                titleLabel.text = nil
            }
        }
    }


    private func prepare() {
        iconImageView.clipsToBounds = true
        titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: titleFontSize)
        addSubview(iconImageView)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        updateShadowPath()
        layer.shadowColor = shadowColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
    }

    private func updateShadowPath() {
        let iconFrame = CGRect(x: iconImageView.frame.origin.x,
                               y: iconImageView.frame.origin.y + shadowOffset,
                               width: iconImageView.frame.width,
                               height: iconImageView.frame.height)
        let shadowPath = UIBezierPath(ovalIn: iconFrame)
        layer.shadowPath = shadowPath.cgPath
    }

}
