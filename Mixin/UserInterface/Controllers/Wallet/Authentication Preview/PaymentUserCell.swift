import UIKit
import SDWebImage

final class PaymentUserCell: UICollectionViewCell {
    
    enum Checkmark {
        case yes
        case no
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var identityNumberLabel: UILabel!
    @IBOutlet weak var badgeImageView: SDAnimatedImageView!
    
    var checkmark: Checkmark? {
        didSet {
            switch checkmark {
            case .yes:
                checkmarkImageView.image = R.image.user_checkmark_yes()
            case .no:
                checkmarkImageView.image = R.image.user_checkmark_no()
            case nil:
                checkmarkImageViewIfLoaded?.isHidden = true
            }
        }
    }
    
    private var checkmarkImageViewIfLoaded: UIImageView?
    
    private var checkmarkImageView: UIImageView {
        if let view = checkmarkImageViewIfLoaded {
            view.isHidden = false
            return view
        } else {
            let view = UIImageView()
            view.contentMode = .center
            contentStackView.insertArrangedSubview(view, at: 0)
            contentStackView.setCustomSpacing(10, after: view)
            self.checkmarkImageViewIfLoaded = view
            return view
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(2, after: usernameLabel)
    }
    
}
