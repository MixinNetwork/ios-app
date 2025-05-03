import UIKit
import MixinServices

class TransactionHistoryViewController: UIViewController {
    
    @IBOutlet weak var filtersScrollView: UIScrollView!
    @IBOutlet weak var typeFilterView: TransactionHistoryTypeFilterView!
    @IBOutlet weak var assetFilterView: TransactionHistoryAssetFilterView!
    @IBOutlet weak var recipientFilterView: TransactionHistoryOpponentFilterView!
    @IBOutlet weak var dateFilterView: TransactionHistoryDateFilterView!
    @IBOutlet weak var tableView: UITableView!
    
    let headerReuseIdentifier = "h"
    let queue = OperationQueue()
    
    private let navigationTitleView = NavigationTitleView(title: R.string.localizable.transaction_history())
    
    init() {
        let nib = R.nib.transactionHistoryView
        super.init(nibName: nib.name, bundle: nib.bundle)
        self.queue.maxConcurrentOperationCount = 1
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = navigationTitleView
        tableView.register(R.nib.snapshotCell)
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseIdentifier)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    func updateEmptyIndicator(numberOfItems: Int) {
        tableView.checkEmpty(
            dataCount: numberOfItems,
            text: R.string.localizable.no_transactions(),
            photo: R.image.emptyIndicator.ic_data()!
        )
    }
    
    func withTableViewContentOffsetManaged(_ block: () -> Void) {
        var tableBottomContentOffsetY: CGFloat {
            tableView.adjustedContentInset.vertical + tableView.contentSize.height - tableView.frame.height
        }
        
        let distanceToBottom = tableView.contentSize.height - tableView.contentOffset.y
        let wasAtTableTop = tableView.contentOffset.y < 1
        let wasAtTableBottom = abs(tableView.contentOffset.y - tableBottomContentOffsetY) < 1
        block()
        tableView.layoutIfNeeded() // Important, ensures `tableView.contentSize` is correct
        let contentOffset: CGPoint
        if wasAtTableTop {
            Logger.general.debug(category: "TxnHistory", message: "Going to table top")
            contentOffset = .zero
        } else if wasAtTableBottom {
            Logger.general.debug(category: "TxnHistory", message: "Going to table bottom")
            contentOffset = CGPoint(x: 0, y: tableBottomContentOffsetY)
        } else {
            Logger.general.debug(category: "TxnHistory", message: "Going to managed offset")
            let contentSizeAfter = tableView.contentSize
            contentOffset = CGPoint(
                x: tableView.contentOffset.x,
                y: max(tableView.contentOffset.y, contentSizeAfter.height - distanceToBottom)
            )
        }
        tableView.setContentOffset(contentOffset, animated: false)
    }
    
}
