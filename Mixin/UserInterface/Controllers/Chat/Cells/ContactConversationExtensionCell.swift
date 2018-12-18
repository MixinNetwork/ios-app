import UIKit

class ContactConversationExtensionCell: UICollectionViewCell {
    
    @IBOutlet weak var avatarContainerView: UIView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sendLabel: UILabel!
    
    let blurView = UIVisualEffectView(effect: nil)
    
    private lazy var effect = UIBlurEffect(style: .dark)
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        avatarContainerView.insertSubview(blurView, belowSubview: sendLabel)
        blurView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    private func updateAppearance() {
        UIView.performWithoutAnimation {
            blurView.effect = isSelected ? effect : nil
            sendLabel.isHidden = !isSelected
        }
    }
    
}
