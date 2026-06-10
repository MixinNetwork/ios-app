import UIKit

final class NoTokenIndicatorCell: UICollectionViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        label.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        label.text = R.string.localizable.no_tokens().uppercased()
    }
    
}
