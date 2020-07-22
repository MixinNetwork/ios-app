import UIKit

class GroupCallMemberCell: UICollectionViewCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var connectingView: GroupCallMemberConnectingView!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = bounds.width / 2
        connectingView.layer.cornerRadius = bounds.width / 2
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
    }
    
}
