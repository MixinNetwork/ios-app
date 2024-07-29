import UIKit

final class AuthenticationPreviewInfoCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var labelStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var primaryLabel: UILabel!
    @IBOutlet weak var secondaryLabel: UILabel!
    @IBOutlet weak var disclosureImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        labelStackView.setCustomSpacing(8, after: captionLabel)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disclosureImageView.isHidden = true
    }
    
    func setPrimaryLabel(usesBoldFont: Bool) {
        let weight: UIFont.Weight = usesBoldFont ? .medium : .regular
        primaryLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: weight),
                             adjustForContentSize: true)
    }
    
}
