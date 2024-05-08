import UIKit
import MixinServices

class Web3TransactionViewController: ColumnListViewController {
    
    private var token: Web3Token
    private var transaction: Web3Transaction
    
    init(token: Web3Token, transaction: Web3Transaction) {
        self.token = token
        self.transaction = transaction
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tableHeaderView = R.nib.web3TransactionHeaderView(withOwner: nil)!
        tableHeaderView.render(transaction: transaction)
        tableView.tableHeaderView = tableHeaderView
        self.tableHeaderView = tableHeaderView
        layoutTableHeaderView()
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        tableView.register(R.nib.snapshotColumnCell)
        tableView.dataSource = self
        tableView.delegate = self
        
        reloadData()
    }
    
    class func instance(web3Token token: Web3Token, transaction: Web3Transaction) -> UIViewController {
        let snapshot = Web3TransactionViewController(token: token, transaction: transaction)
        let container = ContainerViewController.instance(viewController: snapshot, title: R.string.localizable.transaction())
        return container
    }
    
}

extension Web3TransactionViewController {
    
    enum TransactionKey: ColumnKey {
        case id
        case transactionHash
        case from
        case to
        case date
        case status
        
        var localized: String {
            switch self {
            case .id:
                return R.string.localizable.transaction_id()
            case .transactionHash:
                return R.string.localizable.transaction_hash()
            case .from:
                return R.string.localizable.from()
            case .to:
                return R.string.localizable.to()
            case .date:
                return R.string.localizable.date()
            case .status:
                return R.string.localizable.status()
            }
        }
        
        var allowCopy: Bool {
            switch self {
            case .id, .transactionHash, .from,
                    .to:
                true
            default:
                false
            }
        }
    }
    
    class TransactionColumn: Column {
        
        init(key: TransactionKey, value: String, style: Column.Style = []) {
            super.init(key: key, value: value, style: style)
        }
        
    }
    
    private func reloadData() {
        var columns: [TransactionColumn] = []
        
        columns.append(TransactionColumn(key: .id, value: transaction.id))
        columns.append(TransactionColumn(key: .transactionHash, value: transaction.transactionHash))
        
        columns.append(TransactionColumn(key: .from, value: transaction.sender))
        columns.append(TransactionColumn(key: .to, value: transaction.receiver))
        
        columns.append(TransactionColumn(key: .date, value: DateFormatter.dateFull.string(from: transaction.createdAt.toUTCDate())))
        columns.append(TransactionColumn(key: .status, value: transaction.status.capitalized))
        self.columns = columns
        tableView.reloadData()
    }
}
