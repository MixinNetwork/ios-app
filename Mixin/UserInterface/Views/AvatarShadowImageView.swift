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
        iconImageView.frame = bounds
        iconImageView.layer.cornerRadius = iconImageView.bounds.width / 2
        updateShadowPath()
    }

    func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }

    func setGroupImage(with iconUrl: String, conversationId: String) {
        titleLabel.text = nil
        iconImageView.backgroundColor = .clear

        if !iconUrl.isEmpty {
            iconImageView.sd_setImage(with: MixinFile.groupIconsUrl.appendingPathComponent(iconUrl))
        } else {
            iconImageView.image = #imageLiteral(resourceName: "ic_conversation_group")
        }
    }

    func setImage(with url: String, identityNumber: String, name: String, placeholder: Bool = true) {
        if let url = URL(string: url) {
            titleLabel.text = nil
            iconImageView.backgroundColor = .clear
            let placeholder = placeholder ? #imageLiteral(resourceName: "ic_place_holder") : nil
            iconImageView.sd_setImage(with: url, placeholderImage: placeholder, options: .lowPriority)
        } else {
            if let number = Int64(identityNumber) {
                iconImageView.image = UIImage(named: "color\(number % 24 + 1)")
                iconImageView.backgroundColor = .clear
            } else {
                iconImageView.image = nil
                iconImageView.backgroundColor = UIColor(rgbValue: 0xaaaaaa)
            }
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
        let iconFrame = CGRect(x: 0,
                               y: iconImageView.frame.origin.y + shadowOffset,
                               width: iconImageView.frame.width,
                               height: iconImageView.frame.height)
        let shadowPath = UIBezierPath(ovalIn: iconFrame)
        layer.shadowPath = shadowPath.cgPath
    }

}
