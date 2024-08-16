import UIKit

final class TokenInfoCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var primaryContentLabel: UILabel!
    @IBOutlet weak var secondaryContentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        secondaryContentLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        contentStackView.setCustomSpacing(6, after: primaryContentLabel)
    }
    
}
