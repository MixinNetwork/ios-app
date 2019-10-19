import UIKit

class SharedMediaTableViewController: UIViewController, SharedMediaContentViewController {
    
    let tableView = UITableView()
    let headerReuseId = "header"
    
    var conversationId: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.register(SharedMediaTableHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableView.rowHeight = 90
        tableView.sectionHeaderHeight = 40
        tableView.separatorStyle = .none
    }
    
}
