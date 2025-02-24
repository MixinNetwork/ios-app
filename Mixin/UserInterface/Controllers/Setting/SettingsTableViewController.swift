import UIKit

class SettingsTableViewController: UIViewController {
    
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        adjustTableViewBottomInset()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        adjustTableViewBottomInset()
    }
    
    private func adjustTableViewBottomInset() {
        if view.safeAreaInsets.bottom > 20 {
            tableView.contentInset.bottom = 0
        } else {
            tableView.contentInset.bottom = 20
        }
    }
    
}
