import UIKit
import MixinServices

final class Web3TokenViewController: UIViewController {
    
    private let tableView = UITableView()
    
    private let kind: Web3Chain.Kind
    private let address: String
    private let token: Web3Token
    
    private var transactions: [Web3Transaction]?
    
    init(kind: Web3Chain.Kind, address: String, token: Web3Token) {
        self.kind = kind
        self.address = address
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = token.name
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.backgroundColor = R.color.background()
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        tableView.register(R.nib.web3TransactionCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset.bottom = 10
        let tableHeaderView = R.nib.web3TokenHeaderView(withOwner: nil)!
        tableHeaderView.render(token: token)
        tableHeaderView.addTarget(self,
                                  send: #selector(send(_:)),
                                  receive: #selector(receive(_:)))
        tableView.tableHeaderView = tableHeaderView
        layoutTableHeaderView()
        tableView.tableFooterView = R.nib.loadingIndicatorTableFooterView(withOwner: nil)!
        loadTransactions()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            layoutTableHeaderView()
        }
    }
    
    private func loadTransactions() {
        let tokenID: Web3API.TokenID = switch token.chainID {
        case Web3Token.ChainID.solana:
                .assetKey(token.assetKey)
        default:
                .fungibleID(token.fungibleID)
        }
        Web3API.transactions(address: address, chainID: token.chainID, tokenID: tokenID) { result in
            switch result {
            case .success(let transactions):
                self.transactions = transactions
                self.tableView.reloadData()
                self.tableView.tableFooterView = if transactions.isEmpty {
                    R.nib.noTransactionFooterView(withOwner: self)
                } else {
                    nil
                }
            case .failure(let error):
                Logger.web3.warn(category: "Web3TokenViewController", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.loadTransactions()
                }
            }
        }
    }
    
    private func layoutTableHeaderView() {
        guard let tableHeaderView = tableView.tableHeaderView else {
            return
        }
        let sizeToFit = CGSize(width: tableHeaderView.frame.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let height = tableHeaderView.systemLayoutSizeFitting(sizeToFit).height
        tableHeaderView.frame.size.height = height
        tableView.tableHeaderView = tableHeaderView
    }
    
    @objc private func send(_ sender: Any) {
        guard let chain = Web3Chain.chain(web3ChainID: token.chainID) else {
            return
        }
        let payment = Web3SendingTokenPayment(chain: chain, token: token, fromAddress: address)
        let selector = Web3TokenReceiverViewController(payment: payment)
        navigationController?.pushViewController(selector, animated: true)
    }
    
    @objc private func receive(_ sender: Any) {
        let source = Web3ReceiveSourceViewController(kind: kind, address: address)
        navigationController?.pushViewController(source, animated: true)
    }
    
}

// MARK: - UITableViewDataSource
extension Web3TokenViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        transactions?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3transaction, for: indexPath)!
        if let transaction = transactions?[indexPath.row] {
            cell.render(transaction: transaction)
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension Web3TokenViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let transaction = transactions?[indexPath.row] {
            let viewController = Web3TransactionViewController(token: token, transaction: transaction)
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
}
