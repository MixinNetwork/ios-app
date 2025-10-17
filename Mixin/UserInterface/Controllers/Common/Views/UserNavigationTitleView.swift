import UIKit
import SDWebImage
import MixinServices

final class UserNavigationTitleView: UIStackView {
    
    init(title: String, user: UserItem) {
        super.init(frame: .zero)
        
        axis = .vertical
        distribution = .fill
        alignment = .center
        spacing = 2
        
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.text()
        titleLabel.text = title
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        addArrangedSubview(titleLabel)
        
        let iconFrame = CGRect(x: 0, y: 0, width: 16, height: 16)
        
        let avatarImageView = AvatarImageView(frame: iconFrame)
        avatarImageView.titleFontSize = 9
        
        let usernameLabel = UILabel()
        usernameLabel.font = .preferredFont(forTextStyle: .caption1)
        usernameLabel.adjustsFontForContentSizeCategory = true
        usernameLabel.textColor = R.color.text_tertiary()
        usernameLabel.text = user.fullName
        usernameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let userStackView = UIStackView(arrangedSubviews: [
            avatarImageView, usernameLabel
        ])
        userStackView.axis = .horizontal
        userStackView.distribution = .fill
        userStackView.alignment = .center
        userStackView.spacing = 6
        addArrangedSubview(userStackView)
        avatarImageView.snp.makeConstraints { make in
            make.width.height.equalTo(16)
        }
        
        if let badgeImage = user.badgeImage {
            let badgeImageView = SDAnimatedImageView(frame: iconFrame)
            badgeImageView.image = badgeImage
            userStackView.addArrangedSubview(badgeImageView)
            badgeImageView.snp.makeConstraints { make in
                make.width.height.equalTo(16)
            }
        }
        
        avatarImageView.setImage(with: user)
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}
