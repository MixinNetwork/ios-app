import UIKit
import MixinServices

class MultisigUsersWindow: BottomSheetView {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!

    private var users: [UserResponse] = []

    var onDismiss: (() -> Void)?
    
    func render(users: [UserResponse], isSender: Bool) {
        self.users = users
        if isSender {
            titleLabel.text = R.string.localizable.multisig_senders()
        } else {
            titleLabel.text = R.string.localizable.multisig_receivers()
        }
        prepareTableView()
        tableView.reloadData()
    }

    override func dismissPopupControllerAnimated() {
        onDismiss?()
        super.dismissPopupControllerAnimated()
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    class func instance() -> MultisigUsersWindow {
        return Bundle.main.loadNibNamed("MultisigUsersWindow", owner: nil, options: nil)?.first as! MultisigUsersWindow
    }
}

extension MultisigUsersWindow: UITableViewDelegate, UITableViewDataSource {

    private func prepareTableView() {
        tableView.register(UINib(nibName: "MultisigUserCell", bundle: nil), forCellReuseIdentifier: MultisigUserCell.cellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MultisigUserCell.cellIdentifier) as! MultisigUserCell
        cell.render(user: users[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: indexPath.row > 0)
    }
}
