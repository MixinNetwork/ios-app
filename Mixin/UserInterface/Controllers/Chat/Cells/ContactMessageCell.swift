import UIKit

class ContactMessageCell: CardMessageCell {
    
    static let titleSpacing: CGFloat = 6
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    
    let fullnameLabel = UILabel()
    let idLabel = UILabel()
    let verifiedImageView = UIImageView()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        fullnameLabel.font = ContactMessageViewModel.fullnameFont
        fullnameLabel.textColor = .text
        fullnameLabel.adjustsFontForContentSizeCategory = true
        fullnameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fullnameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        verifiedImageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        verifiedImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        verifiedImageView.contentMode = .left
        idLabel.font = ContactMessageViewModel.idFont
        idLabel.textColor = .accessoryText
        idLabel.adjustsFontForContentSizeCategory = true
        let stackView = UIStackView(arrangedSubviews: [fullnameLabel, verifiedImageView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = Self.titleSpacing
        rightView.addSubview(stackView)
        rightView.addSubview(idLabel)
        stackView.snp.makeConstraints { (make) in
            make.leading.trailing.top.equalToSuperview()
        }
        idLabel.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(stackView.snp.bottom).offset(4)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? ContactMessageViewModel {
            fullnameLabel.text = viewModel.message.sharedUserFullName
            idLabel.text = viewModel.message.sharedUserIdentityNumber
            avatarImageView.setImage(with: viewModel.message.sharedUserAvatarUrl, userId: viewModel.message.sharedUserId ?? "", name: viewModel.message.sharedUserFullName)
            if let image = viewModel.verifiedImage {
                verifiedImageView.image = image
                verifiedImageView.isHidden = false
            } else {
                verifiedImageView.isHidden = true
            }
        }
    }
    
}
