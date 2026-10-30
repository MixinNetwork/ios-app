import UIKit
import MixinServices

final class ExploreContactCell: UICollectionViewCell {
    
    static let reuseIdentifier = "ExploreContactCell"
    
    var peerInfoViewHeight: CGFloat = 42 {
        didSet {
            peerInfoViewHeightConstraint.constant = peerInfoViewHeight
        }
    }
    
    private let peerInfoView = PeerInfoView()
    private let externalIndicatorImageView = UIImageView(
        image: R.image.external_indicator_arrow_bold()?.withRenderingMode(.alwaysTemplate),
    )
    
    private weak var peerInfoViewHeightConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView = SelectedCellBackgroundView()
        isAccessibilityElement = true
        accessibilityTraits = .button
        peerInfoView.backgroundColor = .clear
        peerInfoView.avatarImageView.hasShadow = false
        externalIndicatorImageView.tintColor = R.color.icon_tint_tertiary()
        externalIndicatorImageView.contentMode = .center
        externalIndicatorImageView.isHidden = true
        externalIndicatorImageView.setContentHuggingPriority(.required, for: .horizontal)
        externalIndicatorImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stackView = UIStackView(arrangedSubviews: [peerInfoView, externalIndicatorImageView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
                .inset(UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16))
        }
        externalIndicatorImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }
        peerInfoView.translatesAutoresizingMaskIntoConstraints = false
        let peerInfoViewHeightConstraint = peerInfoView.heightAnchor.constraint(
            equalToConstant: peerInfoViewHeight,
        )
        peerInfoViewHeightConstraint.isActive = true
        self.peerInfoViewHeightConstraint = peerInfoViewHeightConstraint
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        peerInfoView.prepareForReuse()
        externalIndicatorImageView.isHidden = true
        accessibilityLabel = nil
    }
    
    func load(user: User, externalIndicator: Bool) {
        peerInfoView.render(user: user, description: .identityNumber)
        externalIndicatorImageView.isHidden = !externalIndicator
        accessibilityLabel = "\(user.fullName ?? ""), \(user.identityNumber)"
    }
    
    func load(user: UserItem) {
        peerInfoView.render(user: user)
        externalIndicatorImageView.isHidden = true
        accessibilityLabel = "\(user.fullName), \(user.identityNumber)"
    }
    
    func load(result: UserSearchResult) {
        peerInfoView.render(result: result)
        externalIndicatorImageView.isHidden = true
        accessibilityLabel = "\(result.user.fullName), \(result.user.identityNumber)"
    }
    
    func load(result: AppUserSearchResult, isFavorite: Bool) {
        peerInfoView.render(result: result)
        externalIndicatorImageView.isHidden = !isFavorite
        accessibilityLabel = "\(result.user.fullName ?? ""), \(result.user.identityNumber)"
    }
    
    func loadAsFavoriteAppManager() {
        externalIndicatorImageView.isHidden = true
        peerInfoView.avatarImageView.image = R.image.edit_favorite_app()
        peerInfoView.titleLabel.text = R.string.localizable.my_favorite_bots()
        peerInfoView.badgeImageView.isHidden = true
        peerInfoView.superscriptLabel.text = nil
        peerInfoView.prefixIconImageView.isHidden = true
        peerInfoView.descriptionLabel.text = R.string.localizable.add_or_remove_favorite_bots()
        peerInfoView.descriptionLabel.isHidden = false
        accessibilityLabel = [peerInfoView.titleLabel.text, peerInfoView.descriptionLabel.text]
            .compactMap({ $0 })
            .joined(separator: ", ")
    }
    
}
