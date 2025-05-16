import UIKit

final class MaliciousTokenWarningCell: UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.backgroundColor = R.color.red()?.withAlphaComponent(0.2)
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        label.text = R.string.localizable.reputation_spam_warning()
    }
    
}
