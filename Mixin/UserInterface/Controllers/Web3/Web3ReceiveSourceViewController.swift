import UIKit
import MixinServices

final class Web3ReceiveSourceViewController: UIViewController {
    
    private enum Source: Int, CaseIterable {
        case mixinWallet = 0
        case address = 1
    }
    
    private let kind: Web3Chain.Kind
    private let address: String
    private let tableView = UITableView()
    
    init(kind: Web3Chain.Kind, address: String) {
        self.kind = kind
        self.address = address
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
        case .mixinWallet:
            cell.iconImageView.image = R.image.token_receiver_contact()
            cell.titleLabel.text = R.string.localizable.from_mixin_wallet()
            cell.subtitleLabel.text = R.string.localizable.contact_mixin_id(myIdentityNumber)
        case .address:
            cell.iconImageView.image = R.image.token_receiver_address()
            cell.titleLabel.text = R.string.localizable.from_address()
            cell.subtitleLabel.text = R.string.localizable.receive_from_address_description()
        }
        cell.freeLabel.isHidden = true
        return cell
    }
    
}

extension Web3ReceiveSourceViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let destination = Source(rawValue: indexPath.row)!
        switch destination {
        case .mixinWallet:
            let selector = Web3TransferTokenSelectorViewController<TokenItem>()
            selector.onSelected = { [address] token in
                guard let chain = self.kind.chains.first(where: { $0.mixinChainID == token.chainID }) else {
                    return
                }
                let input = WithdrawInputAmountViewController(
                    tokenItem: token,
                    destination: .web3(address: address, chain: chain.name)
                )
                self.navigationController?.pushViewController(input, animated: true)
            }
            present(selector, animated: true)
            let chainIDs = kind.chains.compactMap(\.mixinChainID)
            DispatchQueue.global().async { [weak selector] in
                let tokens = TokenDAO.shared.positiveBalancedTokens(chainIDs: chainIDs)
                DispatchQueue.main.async {
                    selector?.reload(tokens: tokens)
                }
            }
        case .address:
            let deposit = Web3DepositViewController(kind: kind, address: address)
            navigationController?.pushViewController(deposit, animated: true)
        }
    }
    
}
