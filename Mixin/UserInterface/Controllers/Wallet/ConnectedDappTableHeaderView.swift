import UIKit

final class ConnectedDappTableHeaderView: UIView {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var hostLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        stackView.setCustomSpacing(10, after: imageView)
        stackView.setCustomSpacing(4, after: nameLabel)
        stackView.setCustomSpacing(12, after: hostLabel)
    }
    
}
