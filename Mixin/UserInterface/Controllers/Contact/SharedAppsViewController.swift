import UIKit
import MixinServices

class SharedAppsViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    var users = [User]() {
        didSet {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize.height = 340
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension SharedAppsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.shared_app, for: indexPath)!
        let user = users[indexPath.row]
        cell.infoView.render(user: user, userBiographyAsSubtitle: true)
        return cell
    }
    
}

extension SharedAppsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let presenting = presentingViewController else {
            return
        }
        let user = users[indexPath.row]
        let item = UserItem.createUser(from: user)
        dismiss(animated: true) {
            let vc = UserProfileViewController(user: item)
            presenting.present(vc, animated: true, completion: nil)
        }
    }
    
}
