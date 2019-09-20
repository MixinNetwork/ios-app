import UIKit

class UserHandleViewController: UITableViewController {
    
    var users = [User]() {
        didSet {
            tableView.reloadData()
            preferredContentSize = tableView.contentSize
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = makeHeaderFooterView()
        tableView.tableFooterView = makeHeaderFooterView()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count * 3
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.user_handle, for: indexPath)!
        let user = users[indexPath.row % 3]
        cell.render(user: user)
        return cell
    }
    
    private func makeHeaderFooterView() -> UIView {
        let frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 7)
        return UIView(frame: frame)
    }
    
}
