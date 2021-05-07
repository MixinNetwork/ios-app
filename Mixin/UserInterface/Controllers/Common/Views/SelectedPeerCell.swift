import UIKit
import MixinServices

protocol SelectedPeerCellDelegate: AnyObject {
    func selectedPeerCellDidSelectRemove(_ cell: UICollectionViewCell)
}

class SelectedPeerCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var nameLabel: UILabel!
    
    weak var delegate: SelectedPeerCellDelegate?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
    }
    
    @IBAction func removeAction(_ sender: Any) {
        delegate?.selectedPeerCellDidSelectRemove(self)
    }
    
    func render(member: CircleMember) {
        if member.category == ConversationCategory.GROUP.rawValue {
            imageView.setGroupImage(with: member.iconUrl)
        } else {
            imageView.setImage(with: member.iconUrl,
                               userId: member.userId ?? "",
                               name: member.name)
        }
        nameLabel.text = member.name
    }
    
    func render(receiver: MessageReceiver) {
        switch receiver.item {
        case .group(let conversation):
            imageView.setGroupImage(conversation: conversation)
        case .user(let user):
            imageView.setImage(with: user)
        }
        nameLabel.text = receiver.name
    }
    
    func render(item: UserItem) {
        imageView.setImage(with: item)
        nameLabel.text = item.fullName
    }
    
}
