import UIKit

class ContactMessageCell: CardMessageCell {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var verifiedImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        idLabel.snp.makeConstraints { (make) in
            make.trailing.equalTo(timeLabel.snp.leading)
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

            if viewModel.message.sharedUserIsVerified {
                verifiedImageView.image = R.image.ic_user_verified()
                verifiedImageView.isHidden = false
            } else if !viewModel.message.sharedUserAppId.isEmpty {
                verifiedImageView.image = R.image.ic_user_bot()
                verifiedImageView.isHidden = false
            } else {
                verifiedImageView.isHidden = true
            }
        }
    }

}
