import UIKit

class UserHandleViewController: UITableViewController, ConversationAccessible {
    
    var users = [User]()
    
    private var filteredUsers = [User]()
    private var keyword: String?
    private var onScrollingAnimationEnd: (() -> ())?
    
    private lazy var tableHeaderView: UIView = {
        let frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 100)
        let view = UserHandleTableHeaderView(frame: frame)
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var tableFooterView: UIView = {
        let frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 7)
        let view = UIView(frame: frame)
        view.backgroundColor = .white
        let bottomFillingBackgroundView = UIView()
        bottomFillingBackgroundView.backgroundColor = .white
        view.addSubview(bottomFillingBackgroundView)
        bottomFillingBackgroundView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.snp.bottom)
            make.height.equalTo(900)
        }
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear
        tableView.tableHeaderView = tableHeaderView
        tableView.tableFooterView = tableFooterView
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let contentHeight = min(CGFloat(filteredUsers.count), 3.5) * tableView.rowHeight + 7
        let tableHeaderHeight = tableView.frame.height - contentHeight
        if tableHeaderView.frame.height != tableHeaderHeight {
            tableHeaderView.frame.size.height = tableHeaderHeight
            tableView.tableHeaderView = tableHeaderView
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredUsers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.user_handle, for: indexPath)!
        let user = filteredUsers[indexPath.row]
        cell.render(user: user, keyword: keyword)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = filteredUsers[indexPath.row]
        conversationViewController?.inputUserHandle(with: user)
    }
    
    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        onScrollingAnimationEnd?()
        onScrollingAnimationEnd = nil
    }
    
    func reload(with keyword: String, completion: ((Bool) -> ())?) {
        if keyword.hasPrefix("@700") {
            self.keyword = keyword
        } else {
            self.keyword = nil
        }
        let hadContent = !filteredUsers.isEmpty
        let filteredUsers: [User]
        if let keyword = self.keyword {
            let identityNumber = keyword[keyword.index(after: keyword.startIndex)...]
            filteredUsers = users.filter({
                $0.identityNumber.hasPrefix(identityNumber)
            })
        } else {
            filteredUsers = []
        }
        let hasContent = !filteredUsers.isEmpty
        if !hadContent && hasContent {
            loadViewIfNeeded()
            self.filteredUsers = filteredUsers
            tableView.reloadData()
            view.setNeedsLayout()
            view.layoutIfNeeded()
            let diff = view.frame.height - tableHeaderView.frame.height
            tableView.contentOffset.y = -diff
            completion?(true)
            onScrollingAnimationEnd = nil
            self.tableView.setContentOffset(.zero, animated: true)
        } else if filteredUsers.isEmpty {
            let diff = view.frame.height - tableHeaderView.frame.height
            let offset = CGPoint(x: 0, y: -diff)
            onScrollingAnimationEnd = { [weak self] in
                if let weakSelf = self {
                    weakSelf.filteredUsers = filteredUsers
                    weakSelf.tableView.reloadData()
                }
                completion?(hasContent)
            }
            self.tableView.setContentOffset(offset, animated: true)
        } else {
            self.filteredUsers = filteredUsers
            onScrollingAnimationEnd = nil
            tableView.reloadData()
            tableView.setContentOffset(.zero, animated: false)
            completion?(hasContent)
        }
    }
    
}
