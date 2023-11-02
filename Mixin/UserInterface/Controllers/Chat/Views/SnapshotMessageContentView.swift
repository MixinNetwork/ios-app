import UIKit

final class SnapshotMessageContentView: UIView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    
    @IBOutlet weak var tokenIconImageView: UIImageView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(8, after: amountLabel)
    }
    
}
