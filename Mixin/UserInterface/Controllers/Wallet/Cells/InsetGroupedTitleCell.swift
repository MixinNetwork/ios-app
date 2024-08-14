import UIKit

final class InsetGroupedTitleCell: UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var disclosureIndicatorView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
}
