import UIKit
import MixinServices

final class MultisigUsersViewController: PopupSelectorViewController {
    
    enum Title {
        case senders
        case receivers
    }
    
    private let titleContent: Title
    private let users: [UserItem]
    
    init(title: Title, users: [UserItem]) {
        self.titleContent = title
        self.users = users
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        tableView.rowHeight = 80
        tableView.register(R.nib.multisigUserCell)
        tableView.dataSource = self
        tableView.delegate = self
        switch titleContent {
        case .senders:
            titleView.titleLabel.text = R.string.localizable.senders()
        case.receivers:
            titleView.titleLabel.text = R.string.localizable.receivers()
        }
        preferredContentSize.height = 490
    }
    
    override func updatePreferredContentHeight() {
        // Set once in `viewDidLoad`
    }
    
}

extension MultisigUsersViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multisig_user, for: indexPath)!
        let user = users[indexPath.row]
        cell.render(user: user)
        return cell
    }
    
}

extension MultisigUsersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}
