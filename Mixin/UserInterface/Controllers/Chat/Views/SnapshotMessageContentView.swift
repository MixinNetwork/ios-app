import UIKit

final class SnapshotMessageContentView: UIView {
    
    enum Corner {
        case round
        case hexagon
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    
    @IBOutlet weak var tokenIconImageView: UIImageView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    
    @IBOutlet weak var tokenIconWidthConstraint: NSLayoutConstraint!
    
    var tokenIconCorner: Corner = .round {
        didSet {
            guard tokenIconCorner != oldValue else {
                return
            }
            setNeedsLayout()
        }
    }
    
    private lazy var hexagonMask = UIImageView(image: R.image.collection_token_mask())
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(8, after: amountLabel)
        tokenIconImageView.layer.masksToBounds = true
        tokenIconImageView.layer.cornerRadius = tokenIconWidthConstraint.constant / 2
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        switch tokenIconCorner {
        case .round:
            tokenIconImageView.layer.cornerRadius = tokenIconWidthConstraint.constant / 2
            tokenIconImageView.mask = nil
        case .hexagon:
            tokenIconImageView.layer.cornerRadius = 0
            hexagonMask.frame = tokenIconImageView.bounds.insetBy(dx: 0, dy: 1)
            tokenIconImageView.mask = hexagonMask
        }
    }
    
}
