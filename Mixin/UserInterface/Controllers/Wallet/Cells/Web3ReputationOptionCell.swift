import UIKit

final class Web3ReputationOptionCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func web3ReputationCellDidTurnOnSwitch(_ cell: Web3ReputationOptionCell)
        func web3ReputationCellDidTurnOffSwitch(_ cell: Web3ReputationOptionCell)
    }
    
    @IBOutlet weak var contentBackgroundView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var activatedSwitch: UISwitch!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentBackgroundView.layer.cornerRadius = 8
        contentBackgroundView.layer.masksToBounds = true
    }
    
    @IBAction func switchValueChanged(_ sender: Any) {
        if activatedSwitch.isOn {
            delegate?.web3ReputationCellDidTurnOnSwitch(self)
        } else {
            delegate?.web3ReputationCellDidTurnOffSwitch(self)
        }
    }
    
}
