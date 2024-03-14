import UIKit

final class AuthenticationPreviewInfoCell: UITableViewCell {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var primaryLabel: UILabel!
    @IBOutlet weak var secondaryLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        stackView.setCustomSpacing(8, after: captionLabel)
    }
    
    func setPrimaryAmountLabel(usesBoldFont: Bool) {
        let weight: UIFont.Weight = usesBoldFont ? .medium : .regular
        primaryLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: weight),
                             adjustForContentSize: true)
    }
    
}
