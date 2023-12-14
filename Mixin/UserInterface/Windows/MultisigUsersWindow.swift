import UIKit
import MixinServices

class MultisigUsersWindow: BottomSheetView {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!

    private var users: [UserItem] = []

    var onDismiss: (() -> Void)?
    
    func render(users: [UserItem], isSender: Bool) {
        self.users = users
        if isSender {
            titleLabel.text = R.string.localizable.senders()
        } else {
            titleLabel.text = R.string.localizable.receivers()
        }
        prepareTableView()
        tableView.reloadData()
    }

    override func dismissPopupController(animated: Bool) {
        onDismiss?()
        super.dismissPopupController(animated: animated)
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }

    class func instance() -> MultisigUsersWindow {
        return Bundle.main.loadNibNamed("MultisigUsersWindow", owner: nil, options: nil)?.first as! MultisigUsersWindow
    }
}

extension MultisigUsersWindow: UITableViewDelegate, UITableViewDataSource {

    private func prepareTableView() {
        tableView.register(R.nib.multisigUserCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
    }

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
