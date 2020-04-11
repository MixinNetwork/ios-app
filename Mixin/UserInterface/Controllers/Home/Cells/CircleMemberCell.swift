import UIKit
import MixinServices

protocol CircleMemberCellDelegate: class {
    func circleMemberCellDidSelectRemove(_ cell: UICollectionViewCell)
}

class CircleMemberCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    weak var delegate: CircleMemberCellDelegate?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
    }
    
    @IBAction func removeAction(_ sender: Any) {
        delegate?.circleMemberCellDidSelectRemove(self)
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
    
}
