import UIKit

class SettingsTableViewController: UIViewController {
    
    let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        } else {
            return LayoutMarginsInsetedTableView(frame: .zero, style: .grouped)
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
    }
    
}
