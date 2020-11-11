import UIKit

class WalletSearchTableViewController: UIViewController {
    
    private(set) lazy var tableView = UITableView(frame: self.view.bounds, style: .grouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        view.addSubview(tableView)
        tableView.backgroundColor = .background
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.rowHeight = 72
        tableView.estimatedRowHeight = 72
        tableView.keyboardDismissMode = .onDrag
        tableView.separatorStyle = .none
        let headerFooterFrame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: .leastNormalMagnitude)
        tableView.tableHeaderView = UIView(frame: headerFooterFrame)
        tableView.tableFooterView = UIView(frame: headerFooterFrame)
        tableView.register(R.nib.compactAssetCell)
    }
    
}
