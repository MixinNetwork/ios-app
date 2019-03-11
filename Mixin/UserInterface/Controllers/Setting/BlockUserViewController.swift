import UIKit

class BlockUserViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private let cellReuseId = "block"
    
    private var users = [UserItem]()
    
    private lazy var userWindow = UserWindow.instance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        fetchBlockedUsers()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchBlockedUsers), name: .UserDidChange, object: nil)
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
                weakSelf.tableView.checkEmpty(dataCount: users.count, text: Localized.SETTING_BLOCKED_EMPTY, photo: #imageLiteral(resourceName: "ic_empty_blocked_users"))
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.block()!
        let container = ContainerViewController.instance(viewController: vc, title: Localized.SETTING_BLOCKED)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
}

extension BlockUserViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! BlockUserCell
        cell.render(user: users[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        userWindow.updateUser(user: users[indexPath.row]).presentView()
    }
    
}
