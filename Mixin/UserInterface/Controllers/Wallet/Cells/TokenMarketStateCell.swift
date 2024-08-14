import UIKit

final class TokenMarketStateCell: UITableViewCell {
    
    @IBOutlet weak var leftTitleLabel: UILabel!
    @IBOutlet weak var rightTitleLabel: UILabel!
    @IBOutlet weak var leftContentLabel: UILabel!
    @IBOutlet weak var rightContentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leftContentLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium), adjustForContentSize: true)
        rightContentLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium), adjustForContentSize: true)
    }
    
}
