import UIKit
import MixinServices

final class MultisigUsersWindow: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!

    private let users: [UserItem]
    private let isSender: Bool

    var onDismiss: (() -> Void)?
    
    init(users: [UserItem], isSender: Bool) {
        self.users = users
        self.isSender = isSender
        let nib = R.nib.multisigUsersWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.multisigUserCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        titleLabel.text = isSender ? R.string.localizable.senders() : R.string.localizable.receivers()
    }

    @IBAction func dismissAction(_ sender: Any) {
        let onDismiss = self.onDismiss
        dismiss(animated: true) {
            onDismiss?()
        }
    }

}

extension MultisigUsersWindow: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multisig_user, for: indexPath)!
        cell.render(user: users[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: indexPath.row > 0)
    }
}
