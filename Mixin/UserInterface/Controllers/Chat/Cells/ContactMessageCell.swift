import UIKit

class ContactMessageCell: CardMessageCell<AvatarImageView, ContactMessageCellRightView> {
    
    override func prepare() {
        super.prepare()
        leftView.layer.cornerRadius = ContactMessageViewModel.leftViewSideLength / 2
        leftView.clipsToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        leftView.prepareForReuse()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? ContactMessageViewModel {
            let message = viewModel.message
            rightView.fullnameLabel.text = message.sharedUserFullName
            rightView.idLabel.text = message.sharedUserIdentityNumber
            leftView.setImage(with: viewModel.message.sharedUserAvatarUrl ?? "",
                              userId: viewModel.message.sharedUserId ?? "",
                              name: viewModel.message.sharedUserFullName ?? "")
            if let image = viewModel.verifiedImage {
                rightView.badgeImageView.image = image
                rightView.badgeImageView.isHidden = false
            } else {
                rightView.badgeImageView.isHidden = true
            }
        }
    }
    
}
