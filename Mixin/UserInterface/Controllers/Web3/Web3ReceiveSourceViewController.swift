import UIKit
import MixinServices

final class Web3ReceiveSourceViewController: UIViewController {
    
    private enum Source: Int, CaseIterable {
        case mixinWallet = 0
        case address = 1
    }
    
    private let address: String
    private let chains: [Web3Chain]
    private let tableView = UITableView()
    
    init(address: String, chains: [Web3Chain]) {
        assert(!chains.isEmpty)
        self.address = address
        self.chains = chains
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.backgroundColor = R.color.background()
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.rowHeight = 74
        tableView.separatorStyle = .none
        tableView.register(R.nib.sendingDestinationCell)
        tableView.dataSource = self
        tableView.delegate = self
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
        case .mixinWallet:
            cell.iconImageView.image = R.image.wallet.send_destination_contact()
            cell.titleLabel.text = R.string.localizable.from_mixin_wallet()
            cell.subtitleLabel.text = R.string.localizable.contact_mixin_id(myIdentityNumber)
        case .address:
            cell.iconImageView.image = R.image.wallet.send_destination_address()
            cell.titleLabel.text = R.string.localizable.from_address()
            cell.subtitleLabel.text = R.string.localizable.receive_from_address_description()
        }
        cell.freeLabel.isHidden = true
        cell.disclosureIndicatorImageView.isHidden = false
        return cell
    }
    
}

extension Web3ReceiveSourceViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let destination = Source(rawValue: indexPath.row)!
        switch destination {
        case .mixinWallet:
            let selector = Web3TransferTokenSelectorViewController()
            selector.delegate = self
            present(selector, animated: true)
            let chainIDs = chains.map(\.mixinChainID)
            DispatchQueue.global().async { [weak selector] in
                let tokens = TokenDAO.shared.positiveBalancedTokens(chainIDs: chainIDs)
                DispatchQueue.main.async {
                    selector?.reload(tokens: tokens)
                }
            }
        case .address:
            let deposit = Web3DepositViewController(address: address)
            let container = ContainerViewController.instance(viewController: deposit, title: R.string.localizable.receive())
            navigationController?.pushViewController(container, animated: true)
        }
    }
    
}

extension Web3ReceiveSourceViewController: Web3TransferTokenSelectorViewControllerDelegate {
    
    func web3TransferTokenSelectorViewController(_ viewController: Web3TransferTokenSelectorViewController, didSelectToken token: TokenItem) {
        guard let chain = chains.first(where: { $0.mixinChainID == token.chainID }) else {
            return
        }
        let input = WithdrawInputAmountViewController(tokenItem: token,
                                                      web3WalletAddress: address,
                                                      web3WalletChainName: chain.name)
        let container = ContainerViewController.instance(viewController: input, title: R.string.localizable.send())
        navigationController?.pushViewController(container, animated: true)
    }
    
    func web3TransferTokenSelectorViewController(_ viewController: Web3TransferTokenSelectorViewController, didSelectToken token: Web3Token) {
        
    }
    
}
