import UIKit
import MixinServices

final class Web3ReputationPickerViewController: PopupSelectorViewController {
    
    protocol Delegate: AnyObject {
        
        func web3ReputationPickerViewControllerDidResetOptions(
            _ controller: Web3ReputationPickerViewController,
        )
        
        func web3ReputationPickerViewController(
            _ controller: Web3ReputationPickerViewController,
            didPickOptions options: Set<Web3Reputation.FilterOption>,
        )
        
    }
    
    weak var delegate: Delegate?
    
    private var options: Set<Web3Reputation.FilterOption>
    
    init(options: Set<Web3Reputation.FilterOption>) {
        self.options = options
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_secondary()
        titleView.backgroundColor = R.color.background_secondary()
        titleView.titleLabel.text = R.string.localizable.reputation()
        tableView.backgroundColor = R.color.background_secondary()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(R.nib.web3ReputationOptionCell)
        tableView.register(R.nib.web3ReputationPickerActionCell)
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView.allowsSelection = false
        tableView.dataSource = self
        tableView.reloadData()
    }
    
}

extension Web3ReputationPickerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            Web3Reputation.FilterOption.allCases.count
        } else {
            1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_reputation_option, for: indexPath)!
            switch Web3Reputation.FilterOption.allCases[indexPath.row] {
            case .spam:
                cell.titleLabel.text = R.string.localizable.reputation_spam()
                cell.subtitleLabel.text = R.string.localizable.reputation_spam_description()
                cell.activatedSwitch.isOn = options.contains(.spam)
            }
            cell.delegate = self
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_reputation_picker_action, for: indexPath)!
            cell.delegate = self
            return cell
        }
    }
    
}

extension Web3ReputationPickerViewController: Web3ReputationOptionCell.Delegate {
    
    func web3ReputationCellDidTurnOnSwitch(_ cell: Web3ReputationOptionCell) {
        let indexPath = tableView.indexPath(for: cell)!
        let option = Web3Reputation.FilterOption.allCases[indexPath.row]
        options.insert(option)
    }
    
    func web3ReputationCellDidTurnOffSwitch(_ cell: Web3ReputationOptionCell) {
        let indexPath = tableView.indexPath(for: cell)!
        let option = Web3Reputation.FilterOption.allCases[indexPath.row]
        options.remove(option)
    }
    
}

extension Web3ReputationPickerViewController: Web3ReputationPickerActionCell.Delegate {
    
    func web3ReputationPickerActionCellDidSelectReset(_ cell: Web3ReputationPickerActionCell) {
        delegate?.web3ReputationPickerViewControllerDidResetOptions(self)
        close(cell)
    }
    
    func web3ReputationPickerActionCellDidSelectApply(_ cell: Web3ReputationPickerActionCell) {
        delegate?.web3ReputationPickerViewController(self, didPickOptions: options)
        close(cell)
    }
    
}
