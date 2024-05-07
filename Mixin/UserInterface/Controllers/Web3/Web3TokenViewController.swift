import UIKit
import MixinServices

final class Web3TokenViewController: UIViewController {
    
    private let tableView = UITableView()
    
    private let address: String
    private let token: Web3Token
    
    private var transactions: [Web3Transaction]?
    
    init(address: String, token: Web3Token) {
        self.address = address
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.backgroundColor = R.color.background()
        tableView.rowHeight = 50
        tableView.separatorStyle = .none
        tableView.register(R.nib.web3TransactionCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset.bottom = 10
        loadTransactions()
    }
    
    
    private func loadTransactions() {
        tableView.tableFooterView = R.nib.loadingIndicatorTableFooterView(withOwner: nil)!
        
        Web3API.transactions(address: address, chainID: token.chainID, fungibleID: token.fungibleID) { result in
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
                Logger.web3.warn(category: "Web3 Transactions", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.loadTransactions()
                }
            }
        }
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
//        if let address, let transaction = transactions?[indexPath.row] {
//            let viewController = Web3TokenViewController(address: address, token: token)
//            let container = ContainerViewController.instance(viewController: viewController, title: token.name)
//            navigationController?.pushViewController(container, animated: true)
//        }
    }
    
}
