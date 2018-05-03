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

    func setGroupImage(with iconUrl: String, conversationId: String) {
        titleLabel.text = nil
        backgroundColor = .clear

        if !iconUrl.isEmpty {
            sd_setImage(with: MixinFile.groupIconsUrl.appendingPathComponent(iconUrl))
        } else {
            image = #imageLiteral(resourceName: "ic_conversation_group")
        }
    }

    func setImage(user: ParticipantUser) {
        setImage(with: user.userAvatarUrl, identityNumber: user.userIdentityNumber, name: user.userFullName)
    }

    func setImage(with user: Account) {
        setImage(with: user.avatar_url, identityNumber: user.identity_number, name: user.full_name)
    }

    func setImage(with user: UserItem) {
        setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
    }
    
    func setImage(user: UserResponse) {
        setImage(with: user.avatarUrl, identityNumber: user.identityNumber, name: user.fullName)
    }
    
    func setImage(with url: String, identityNumber: String, name: String) {
        if let url = URL(string: url) {
            titleLabel.text = nil
            backgroundColor = .clear
            sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), options: .lowPriority)
        } else {
            if let number = Int64(identityNumber) {
                image = UIImage(named: "color\(number % 24 + 1)")
                backgroundColor = .clear
            } else {
                image = nil
                backgroundColor = UIColor(rgbValue: 0xaaaaaa)
            }
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
