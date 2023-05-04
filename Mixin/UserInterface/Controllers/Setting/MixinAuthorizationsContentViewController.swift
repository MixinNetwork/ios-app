import UIKit
import MixinServices

class MixinAuthorizationsContentViewController: AuthorizationsContentViewController {
    
    var authorizations: [AuthorizationResponse] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        authorizations.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization, for: indexPath)!
        let app = authorizations[indexPath.row].app
        cell.iconImageView.setImage(with: app.iconUrl, userId: app.appId, name: app.name, placeholder: false)
        cell.titleLabel.text = app.name
        cell.subtitleLabel.text = app.appNumber
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let permission = PermissionsViewController.instance(dataSource: .response(authorizations[indexPath.row]))
        self.navigationController?.pushViewController(permission, animated: true)
    }
    
}
