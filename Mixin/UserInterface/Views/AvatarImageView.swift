import UIKit

class AvatarImageView: CornerImageView {

    @IBInspectable
    var titleFontSize: CGFloat = 17 {
        didSet {
            titleLabel?.font = .systemFont(ofSize: titleFontSize)
        }
    }
    var titleLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }

    func setGroupImage(conversation: ConversationItem) {
        setGroupImage(with: conversation.iconUrl)
    }

    func setGroupImage(with iconUrl: String) {
        titleLabel.text = nil
        backgroundColor = .clear

        if !iconUrl.isEmpty {
            sd_setImage(with: MixinFile.groupIconsUrl.appendingPathComponent(iconUrl))
        } else {
            image = #imageLiteral(resourceName: "ic_conversation_group")
        }
    }

    func setImage(user: ParticipantUser) {
        setImage(with: user.userAvatarUrl, userId: user.userId, name: user.userFullName)
    }

    func setImage(with user: Account) {
        setImage(with: user.avatar_url, userId: user.user_id, name: user.full_name)
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
            backgroundColor = .clear
            let placeholder = placeholder ? #imageLiteral(resourceName: "ic_place_holder") : nil
            sd_setImage(with: url, placeholderImage: placeholder, options: .lowPriority)
        } else {
            image = UIImage(named: "color\(userId.positiveHashCode() % 24 + 1)")
            backgroundColor = .clear
            if let firstLetter = name.first {
                titleLabel.text = String([firstLetter]).uppercased()
            } else {
                titleLabel.text = nil
            }
        }
    }

    private func prepare() {
        titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: titleFontSize)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
    }
    
}
