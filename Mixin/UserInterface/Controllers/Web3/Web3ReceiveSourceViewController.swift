import UIKit
import MixinServices

final class Web3ReceiveSourceViewController: UIViewController {
    
    private enum Source: Int, CaseIterable {
        case privacyWallet = 0
        case address = 1
    }
    
    private let token: Web3TokenItem
    private let tableView = UITableView()
    
    init(token: Web3TokenItem) {
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.receive()
        view.addSubview(tableView)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.register(R.nib.sendingDestinationCell)
        tableView.dataSource = self
        tableView.delegate = self
    }
    
}

extension Web3ReceiveSourceViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension Web3ReceiveSourceViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Source.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
        let destination = Source(rawValue: indexPath.row)!
        switch destination {
        case .privacyWallet:
            cell.iconImageView.image = R.image.token_receiver_contact()
            cell.titleLabel.text = R.string.localizable.privacy_wallet()
            cell.subtitleLabel.text = R.string.localizable.receive_from_privacy_wallets_description()
        case .address:
            cell.iconImageView.image = R.image.token_receiver_address()
            cell.titleLabel.text = R.string.localizable.exchange_or_wallet()
            cell.subtitleLabel.text = R.string.localizable.receive_from_address_description()
        }
        cell.freeLabel.isHidden = true
        return cell
    }
    
}

extension Web3ReceiveSourceViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let address = Web3AddressDAO.shared.address(walletID: token.walletID, chainID: token.chainID)
        guard let address else {
            return
        }
        let destination = Source(rawValue: indexPath.row)!
        switch destination {
        case .privacyWallet:
            let tokenItem: MixinTokenItem
            if let item = TokenDAO.shared.tokenItem(assetID: token.assetID) {
                tokenItem = item
            } else {
                // XXX: It's terrible, but since this token cannot be found in the database,
                // the balance must be zero. Anyway, operations cannot succeed with a zero
                // balance, so just make up some random values to get by.
                let mixinToken = MixinToken(
                    assetID: token.assetID,
                    kernelAssetID: token.kernelAssetID,
                    symbol: token.symbol,
                    name: token.name,
                    iconURL: token.iconURL,
                    btcPrice: "0",
                    usdPrice: token.usdPrice,
                    chainID: token.chainID,
                    usdChange: token.usdChange,
                    btcChange: "0",
                    dust: "0",
                    confirmations: -1,
                    assetKey: "",
                    collectionHash: nil
                )
                tokenItem = MixinTokenItem(
                    token: mixinToken,
                    balance: "0",
                    isHidden: false,
                    chain: token.chain
                )
            }
            let input = WithdrawInputAmountViewController(
                tokenItem: tokenItem,
                destination: .classicWallet(address)
            )
            navigationController?.pushViewController(input, animated: true)
        case .address:
            guard let kind = Web3Chain.chain(chainID: token.chainID)?.kind else {
                return
            }
            let deposit = Web3DepositViewController(kind: kind, address: address.destination)
            navigationController?.pushViewController(deposit, animated: true)
        }
    }
    
}
