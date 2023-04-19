import UIKit
import MixinServices

class BlockedUsersViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private let cellReuseId = "block"
    
    private var users = [UserItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        UserAPI.syncBlockingUsers()
        fetchBlockedUsers()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(fetchBlockedUsers),
                                               name: UserDAO.usersDidChangeNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func fetchBlockedUsers() {
        DispatchQueue.global().async { [weak self] in
            let users = UserDAO.shared.getBlockUsers()
            self?.users = users
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.tableView.reloadData()
                weakSelf.tableView.checkEmpty(dataCount: users.count,
                                              text: R.string.localizable.no_blocked_users(),
                                              photo: R.image.emptyIndicator.ic_blocked_users()!)
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.block()!
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.blocked_users())
        return container
    }
    
}

extension BlockedUsersViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! BlockUserCell
        cell.infoView.render(user: users[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = users[indexPath.row]
        let vc = UserProfileViewController(user: user)
        present(vc, animated: true, completion: nil)
    }
    
}
