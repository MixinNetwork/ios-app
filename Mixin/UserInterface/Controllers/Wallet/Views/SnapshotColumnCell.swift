import UIKit

final class SnapshotColumnCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView(frame: bounds)
        selectedBackgroundView!.backgroundColor = .selectionBackground
    }
    
}
