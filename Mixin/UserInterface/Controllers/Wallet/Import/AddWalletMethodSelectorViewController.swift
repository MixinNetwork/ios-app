import UIKit

final class AddWalletMethodSelectorViewController: PopupSelectorViewController {
    
    enum Method: CaseIterable {
        case mnemonics
    }
    
    var onSelected: ((Method) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_quaternary()
        titleView.backgroundColor = R.color.background_quaternary()
        tableViewTopConstraint.constant = 0
        tableView.backgroundColor = R.color.background_quaternary()
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(R.nib.addTokenMethodCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = switch ScreenHeight.current {
        case .short:
            UIEdgeInsets(top: 0, left: 0, bottom: 72, right: 0)
        case .medium:
            UIEdgeInsets(top: 0, left: 0, bottom: 130, right: 0)
        case .long, .extraLong:
            UIEdgeInsets(top: 0, left: 0, bottom: 260, right: 0)
        }
        titleView.titleLabel.text = R.string.localizable.add_wallet()
    }
    
}

extension AddWalletMethodSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Method.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.add_token_method, for: indexPath)!
        switch Method.allCases[indexPath.row] {
        case .mnemonics:
            cell.iconImageView.image = R.image.add_wallet_mnemonics()
            cell.titleLabel.text = R.string.localizable.import_mnemonic_phrase()
            cell.subtitleLabel.text = R.string.localizable.import_wallets_from_another_wallet()
        }
        return cell
    }
    
}

extension AddWalletMethodSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let method = Method.allCases[indexPath.row]
        presentingViewController?.dismiss(animated: true) { [onSelected] in
            onSelected?(method)
        }
    }
    
}
