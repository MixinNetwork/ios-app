import UIKit
import MixinServices

class AuthorizationsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var networkIndicatorTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorView: ActivityIndicatorView!
    
    private let cellReuseId = "authorization"
    
    private var authorizations = [AuthorizationResponse]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        reload()
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.authorization()!
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_AUTHORIZATIONS)
    }
    
}

extension AuthorizationsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return authorizations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! AuthorizationTableViewCell
        let app = authorizations[indexPath.row].app
        cell.iconImageView.setImage(with: app.iconUrl, userId: app.appId, name: app.name, placeholder: false)
        cell.titleLabel.text = app.name
        cell.subtitleLabel.text = app.appNumber
        return cell
    }
    
}

extension AuthorizationsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let action = UITableViewRowAction(style: .destructive,
                                          title: Localized.ACTION_DEAUTHORIZE,
                                          handler: tableViewCommitDeleteAction)
        return [action]
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

extension AuthorizationsViewController {
    
    private func reload() {
        AuthorizeAPI.shared.authorizations { [weak self] (result) in
            switch result {
            case let .success(response):
                self?.load(authorizations: response)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    private func load(authorizations: [AuthorizationResponse]) {
        self.authorizations = authorizations
        tableView.reloadData()
        tableView.layoutIfNeeded()
        networkIndicatorView.stopAnimating()
        networkIndicatorTopConstraint.constant = networkIndicatorHeightConstraint.constant
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
        tableView.checkEmpty(dataCount: authorizations.count,
                             text: Localized.SETTING_NO_AUTHORIZATIONS,
                             photo: R.image.ic_no_authorization()!)
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let app = authorizations[indexPath.row].app
        let alert = UIAlertController(title: Localized.SETTING_DEAUTHORIZE_CONFIRMATION(name: app.name), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CONFIRM, style: .destructive, handler: { (action) in
            self.removeAuthorization(at: indexPath)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func removeAuthorization(at indexPath: IndexPath) {
        let auth = authorizations[indexPath.row]
        AuthorizeAPI.shared.cancel(clientId: auth.app.appId) { [weak self](result) in
            switch result {
            case .success:
                self?.authorizations.remove(at: indexPath.row)
                self?.tableView.deleteRows(at: [indexPath], with: .automatic)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
}
