import UIKit

final class AddWalletMethodSelectorViewController: PopupSelectorViewController {
    
    var onSelected: ((AddWalletMethod) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_quaternary()
        titleView.backgroundColor = R.color.background_quaternary()
        titleView.titleLabel.text = R.string.localizable.add_wallet()
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
            UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        case .medium:
            UIEdgeInsets(top: 0, left: 0, bottom: 60, right: 0)
        case .long, .extraLong:
            UIEdgeInsets(top: 0, left: 0, bottom: 104, right: 0)
        }
    }
    
}

extension AddWalletMethodSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AddWalletMethod.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.add_token_method, for: indexPath)!
        switch AddWalletMethod.allCases[indexPath.row] {
        case .privateKey:
            cell.iconImageView.image = R.image.add_wallet_private_key()
            cell.titleLabel.text = R.string.localizable.import_private_key()
            cell.subtitleLabel.text = R.string.localizable.import_single_chain_wallet()
        case .mnemonics:
            cell.iconImageView.image = R.image.add_wallet_mnemonics()
            cell.titleLabel.text = R.string.localizable.import_mnemonic_phrase()
            cell.subtitleLabel.text = R.string.localizable.import_wallets_from_another_wallet()
        case .watch:
            cell.iconImageView.image = R.image.watching_wallet()
            cell.titleLabel.text = R.string.localizable.add_watch_address()
            cell.subtitleLabel.text = R.string.localizable.add_watch_address_description()
        }
        return cell
    }
    
}

extension AddWalletMethodSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let method = AddWalletMethod.allCases[indexPath.row]
        presentingViewController?.dismiss(animated: true) { [onSelected] in
            onSelected?(method)
        }
    }
    
}
