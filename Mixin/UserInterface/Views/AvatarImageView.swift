import UIKit

class AvatarImageView: UIView {
    
    @IBInspectable
    var titleFontSize: CGFloat = 17 {
        didSet {
            titleLabel.font = .systemFont(ofSize: titleFontSize)
        }
    }
    
    @IBInspectable
    var hasShadow: Bool = false {
        didSet {
            layer.shadowOpacity = hasShadow ? 0.2 : 0
            setNeedsLayout()
        }
    }

    @IBInspectable
    var hasBorder: Bool = false {
        didSet {
            imageView.layer.borderColor = UIColor.white.cgColor
            imageView.layer.borderWidth = 2
            imageView.setNeedsLayout()
        }
    }
    
    var image: UIImage? {
        get {
            return imageView.image
        }
        set {
            imageView.image = newValue
        }
    }
    
    var isLoadingImage: Bool {
        return imageView.sd_imageURL != nil
    }
    
    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    
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
        layout(imageView: imageView)
        let radius = min(imageView.frame.width, imageView.frame.height) / 2
        imageView.layer.cornerRadius = radius
        updateShadowPath()
    }
    
    func layout(imageView: UIImageView) {
        imageView.frame = bounds
    }
    
    func prepareForReuse() {
        titleLabel.text = nil
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
    }
    
    func setGroupImage(conversation: ConversationItem) {
        setGroupImage(with: conversation.iconUrl)
    }
    
    func setGroupImage(with iconUrl: String) {
        titleLabel.text = nil
        if !iconUrl.isEmpty {
            let url = MixinFile.groupIconsUrl.appendingPathComponent(iconUrl)
            imageView.sd_setImage(with: url, placeholderImage: nil, context: localImageContext)
        } else {
            imageView.image = R.image.ic_conversation_group()
        }
    }
    
    func setImage(user: ParticipantUser) {
        setImage(with: user.userAvatarUrl, userId: user.userId, name: user.userFullName)
    }
    
    func setImage(with user: Account) {
        setImage(with: user.avatar_url, userId: user.user_id, name: user.full_name)
    }
    
    func setImage(with user: User) {
        setImage(with: user.avatarUrl ?? "", userId: user.userId, name: user.fullName ?? "")
    }
    
    func setImage(with user: UserItem) {
        setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
    }
    
    func setImage(user: UserResponse) {
        setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
    }
    
    func setImage(with url: String, userId: String, name: String, placeholder: Bool = true) {
        if let url = URL(string: url) {
            titleLabel.text = nil
            let placeholder = placeholder ? R.image.ic_place_holder() : nil
            imageView.sd_setImage(with: url, placeholderImage: placeholder, options: .lowPriority)
        } else {
            imageView.image = UIImage(named: "AvatarBackground/color\(userId.positiveHashCode() % 24 + 1)")
            if let firstLetter = name.first {
                titleLabel.text = String([firstLetter]).uppercased()
            } else {
                titleLabel.text = nil
            }
        }
    }
    
    private func updateShadowPath() {
        if hasShadow {
            var shadowFrame = imageView.frame
            shadowFrame.origin.y += 5
            let shadowPath = UIBezierPath(ovalIn: shadowFrame)
            layer.shadowPath = shadowPath.cgPath
        } else {
            layer.shadowPath = nil
        }
    }
    
    private func prepare() {
        layer.shadowColor = R.color.shadow()!.cgColor
        layer.shadowRadius = 6
        
        imageView.clipsToBounds = true
        imageView.frame = bounds
        addSubview(imageView)
        
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: titleFontSize)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        titleLabel.snp.makeEdgesEqualToSuperview()
    }
    
}
