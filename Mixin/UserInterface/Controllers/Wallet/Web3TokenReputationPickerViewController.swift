import UIKit
import MixinServices

final class Web3TokenReputationPickerViewController: PopupSelectorViewController {
    
    protocol Delegate: AnyObject {
        
        func web3TokenReputationPickerViewController(
            _ controller: Web3TokenReputationPickerViewController,
            didPickReputation reputation: Web3Token.Reputation
        )
        
    }
    
    weak var delegate: Delegate?
    
    private let reputations = Web3Token.Reputation.allCases
    
    private var selectedReputation: Web3Token.Reputation
    
    init(selectedReputation: Web3Token.Reputation) {
        self.selectedReputation = selectedReputation
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.text = R.string.localizable.alert_type()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(R.nib.web3TokenReputationCell)
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        if let row = reputations.firstIndex(of: selectedReputation) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
    }
    
}

extension Web3TokenReputationPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        reputations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_token_reputation, for: indexPath)!
        let reputation = reputations[indexPath.row]
        switch reputation {
        case .good:
            cell.titleLabel.text = R.string.localizable.reputation_good()
            cell.subtitleLabel.text = R.string.localizable.reputation_good_description()
        case .unknown:
            cell.titleLabel.text = R.string.localizable.reputation_unknown()
            cell.subtitleLabel.text = R.string.localizable.reputation_unknown_description()
        case .spam:
            cell.titleLabel.text = R.string.localizable.reputation_spam()
            cell.subtitleLabel.text = R.string.localizable.reputation_spam_description()
        }
        return cell
    }
    
}

extension Web3TokenReputationPickerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let reputation = reputations[indexPath.row]
        delegate?.web3TokenReputationPickerViewController(self, didPickReputation: reputation)
        presentingViewController?.dismiss(animated: true)
    }
    
}
