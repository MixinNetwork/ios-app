import UIKit

final class PerpetualPlaceholderCell: UICollectionViewCell {
    
    @IBOutlet weak var emptyIndicatorStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    
    var onHelp: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        emptyIndicatorStackView.setCustomSpacing(12, after: iconImageView)
    }
    
    @IBAction func askForHelp(_ sender: Any) {
        onHelp?()
    }
    
}
