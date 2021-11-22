import UIKit

class AuthorizationsContentViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var authorizations: [AuthorizationResponse] = [] {
        didSet {
            tableView.reloadData()
            tableView.layoutIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(removeAuthorization(_:)),
                                               name: PermissionsViewController.authorizationRevokedNotification,
                                               object: nil)
    }
    
    @objc private func removeAuthorization(_ notification: Notification) {
        guard let appId = notification.userInfo?[PermissionsViewController.appIdUserInfoKey] as? String else {
            return
        }
        authorizations = authorizations.filter { (auth) -> Bool in
            auth.app.appId != appId
        }
    }
    
}

extension AuthorizationsContentViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        authorizations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization, for: indexPath)!
        let app = authorizations[indexPath.row].app
        cell.iconImageView.setImage(with: app.iconUrl, userId: app.appId, name: app.name, placeholder: false)
        cell.titleLabel.text = app.name
        cell.subtitleLabel.text = app.appNumber
        return cell
    }
    
}

extension AuthorizationsContentViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let permissionvc = PermissionsViewController.instance(dataSource: .all(authorizations[indexPath.row]))
        self.navigationController?.pushViewController(permissionvc, animated: true)
    }
    
}
