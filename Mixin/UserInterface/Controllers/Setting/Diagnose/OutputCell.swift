import UIKit
import MixinServices

final class OutputCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        descriptionLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    }
    
    func load(output: Output, showAssetID: Bool) {
        titleLabel.text = output.id
        if showAssetID {
            descriptionLabel.text = "\(output.sequence):\(output.state):\(output.asset)"
        } else {
            descriptionLabel.text = "\(output.sequence):\(output.state)"
        }
        amountLabel.text = output.amount
    }
    
}
