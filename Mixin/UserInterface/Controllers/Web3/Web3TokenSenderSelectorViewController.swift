import UIKit
import MixinServices

final class Web3TokenSenderSelectorViewController: UIViewController {
    
    private enum Sender: Int, CaseIterable {
        case myWallets = 0
        case address = 1
    }
    
    private let receivingWallet: Web3Wallet
    private let receivingToken: Web3TokenItem
    private let tableView = UITableView()
    
    private var receivingAddress: Web3Address? {
        Web3AddressDAO.shared.address(
            walletID: receivingWallet.walletID,
            chainID: receivingToken.chainID
        )
    }
    
    init(receivingWallet: Web3Wallet, receivingToken: Web3TokenItem) {
        self.receivingWallet = receivingWallet
        self.receivingToken = receivingToken
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

extension Web3TokenSenderSelectorViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension Web3TokenSenderSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Sender.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
        let destination = Sender(rawValue: indexPath.row)!
        switch destination {
        case .myWallets:
            cell.iconImageView.image = R.image.token_receiver_contact()
            cell.titleLabel.text = R.string.localizable.my_wallet()
            cell.titleTag = nil
            cell.descriptionLabel.text = R.string.localizable.receive_from_other_wallets_description()
        case .address:
            cell.iconImageView.image = R.image.token_receiver_address()
            cell.titleLabel.text = R.string.localizable.exchanges_or_wallets()
            cell.titleTag = nil
            cell.descriptionLabel.text = R.string.localizable.receive_from_address_description()
        }
        return cell
    }
    
}

extension Web3TokenSenderSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let destination = Sender(rawValue: indexPath.row)!
        switch destination {
        case .myWallets:
            let selector = WalletSelectorViewController(
                intent: .pickSender,
                excluding: .common(receivingWallet),
                supportingChainWith: receivingToken.chainID
            )
            selector.delegate = self
            present(selector, animated: true)
        case .address:
            let deposit = DepositViewController(
                wallet: receivingWallet,
                token: receivingToken,
                switchingBetweenNetworks: true
            )
            navigationController?.pushViewController(deposit, animated: true)
        }
    }
    
}

extension Web3TokenSenderSelectorViewController: WalletSelectorViewController.Delegate {
    
    func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectWallet wallet: Wallet) {
        guard let receivingAddress else {
            return
        }
        switch wallet {
        case .privacy:
            let tokenItem: MixinTokenItem
            if let item = TokenDAO.shared.tokenItem(assetID: receivingToken.assetID) {
                tokenItem = item
            } else {
                // XXX: It's terrible, but since this token cannot be found in the database,
                // the balance must be zero. Anyway, operations cannot succeed with a zero
                // balance, so just make up some random values to get by.
                let mixinToken = MixinToken(
                    assetID: receivingToken.assetID,
                    kernelAssetID: receivingToken.kernelAssetID,
                    symbol: receivingToken.symbol,
                    name: receivingToken.name,
                    iconURL: receivingToken.iconURL,
                    btcPrice: "0",
                    usdPrice: receivingToken.usdPrice,
                    chainID: receivingToken.chainID,
                    usdChange: receivingToken.usdChange,
                    btcChange: "0",
                    dust: "0",
                    confirmations: -1,
                    assetKey: receivingToken.assetKey,
                    precision: receivingToken.precision,
                    collectionHash: nil
                )
                tokenItem = MixinTokenItem(
                    token: mixinToken,
                    balance: "0",
                    isHidden: false,
                    chain: receivingToken.chain
                )
            }
            let input = WithdrawInputAmountViewController(
                tokenItem: tokenItem,
                destination: .commonWallet(receivingWallet, receivingAddress)
            )
            navigationController?.pushViewController(input, animated: true)
        case .common(let sendingWallet):
            guard let chain = Web3Chain.chain(chainID: receivingToken.chainID) else {
                return
            }
            guard let sendingAddress = Web3AddressDAO.shared.address(walletID: sendingWallet.walletID, chainID: chain.chainID) else {
                return
            }
            let sendingToken = if let token = Web3TokenDAO.shared.token(walletID: sendingWallet.walletID, assetID: receivingToken.assetID) {
                token
            } else {
                // XXX: It's terrible, but since this token cannot be found in the database,
                // the balance must be zero. Anyway, operations cannot succeed with a zero
                // balance, so just make up some random values to get by.
                Web3TokenItem(token: receivingToken, replacingAmountWith: "0")
            }
            let payment = Web3SendingTokenToAddressPayment(
                chain: chain,
                token: sendingToken,
                fromWallet: sendingWallet,
                fromAddress: sendingAddress,
                toAddress: receivingAddress.destination,
                toAddressLabel: .wallet(.common(receivingWallet)),
            )
            let input = Web3TransferInputAmountViewController(payment: payment)
            navigationController?.pushViewController(input, animated: true)
        case .safe:
            // Cannot send tokens from safe wallets
            return
        }
    }
    
    func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectMultipleWallets wallets: [Wallet]) {
        
    }
    
}
