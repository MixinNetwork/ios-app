import UIKit
import MixinServices

final class MultisigUsersViewController: PopupSelectorViewController {
    
    enum Content {
        case senders
        case receivers
    }
    
    private let content: Content
    private let threshold: Int
    private let users: [UserItem]
    
    init(content: Content, threshold: Int, users: [UserItem]) {
        self.content = content
        self.threshold = threshold
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
        tableView.isScrollEnabled = true
        tableView.contentInset.bottom = 20
        
        let thresholdRepresentation = "\(threshold)/\(users.count)"
        switch content {
        case .senders:
            titleView.titleLabel.text = R.string.localizable.multisig_senders_threshold(thresholdRepresentation)
        case.receivers:
            titleView.titleLabel.text = R.string.localizable.multisig_receivers_threshold(thresholdRepresentation)
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
