import UIKit

final class SendingDestinationCell: UITableViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var freeLabel: InsetLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var disclosureIndicatorImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        freeLabel.contentInset = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .clear
            return view
        }()
    }
    
}
