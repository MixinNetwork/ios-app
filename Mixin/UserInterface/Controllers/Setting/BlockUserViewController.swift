import UIKit

class BlockUserViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var users = [UserItem]()

    private lazy var userWindow = UserWindow.instance()

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareTableView()
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
                self?.tableView.reloadData()
            }
        }
    }

    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.setting.instantiateViewController(withIdentifier: "block"), title: Localized.SETTING_BLOCKED)
    }
    
}

extension BlockUserViewController: UITableViewDelegate, UITableViewDataSource {

    private func prepareTableView() {
        tableView.register(UINib(nibName: "BlockUserCell", bundle: nil), forCellReuseIdentifier: BlockUserCell.cellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = BlockUserCell.cellHeight
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BlockUserCell.cellIdentifier) as! BlockUserCell
        cell.render(user: users[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        userWindow.updateUser(user: users[indexPath.row]).presentPopupControllerAnimated()
    }
    
}


