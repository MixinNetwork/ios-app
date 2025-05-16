import UIKit

final class Web3ReputationPickerActionCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func web3ReputationPickerActionCellDidSelectReset(_ cell: Web3ReputationPickerActionCell)
        func web3ReputationPickerActionCellDidSelectApply(_ cell: Web3ReputationPickerActionCell)
    }
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var applyButton: StateResponsiveButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.text = R.string.localizable.reputation_description()
        resetButton.setTitle(R.string.localizable.reset(), for: .normal)
        applyButton.setTitle(R.string.localizable.apply(), for: .normal)
    }
    
    @IBAction func reset(_ sender: Any) {
        delegate?.web3ReputationPickerActionCellDidSelectReset(self)
    }
    
    @IBAction func apply(_ sender: Any) {
        delegate?.web3ReputationPickerActionCellDidSelectApply(self)
    }
    
}
