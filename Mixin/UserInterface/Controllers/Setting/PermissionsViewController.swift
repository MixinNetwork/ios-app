import UIKit
import MixinServices

class PermissionsViewController: UIViewController {
    
    var authorization: AuthorizationResponse! = nil
    
    private let footerReuseId = "footer"
    
    private var scopes: [(scope: Scope, name: String, desc: String)] = [(scope: Scope, name: String, desc: String)]()
    
    @IBOutlet private var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scopes = Scope.getCompleteScopeInfo(authInfo: authorization)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SeparatorShadowFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.register(R.nib.permissionsTableViewCell)
        tableView.register(R.nib.singleTextTableViewCell)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
    }
    
    class func instance(authorization: AuthorizationResponse) -> UIViewController {
        let permissionvc = R.storyboard.setting.permission()!
        permissionvc.authorization = authorization
        return ContainerViewController.instance(viewController: permissionvc, title: R.string.localizable.setting_permissions())
    }
    
    func removeAuthozationAction() {
        let alert = UIAlertController(title: Localized.SETTING_DEAUTHORIZE_CONFIRMATION(name: authorization.app.name), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CONFIRM, style: .destructive, handler: { (action) in
            AuthorizeAPI.shared.cancel(clientId: self.authorization.app.appId) { [weak self](result) in
                switch result {
                case .success:
                    self?.navigationController?.popViewController(animated: true)
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - Table view data source
extension PermissionsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return 1
        }
        return authorization.scopes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.permission, for: indexPath)!
            let scope = scopes[indexPath.row]
            cell.render(name: scope.name, desc: scope.desc)
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.singleTextCell, for: indexPath)!
            cell.contentLabel.text = R.string.localizable.action_deauthorize()
            cell.contentLabel.textColor = R.color.red()
            return cell
        }
    }
    
}

// MARK: - Table view delegate
extension PermissionsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            self.removeAuthozationAction()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        if section == 0 {
            let createDate = DateFormatter.dateYMD.string(from: authorization.createdAt.toUTCDate())
            let accessedDate = DateFormatter.dateYMD.string(from: authorization.accessedAt.toUTCDate())
            view.text = R.string.localizable.setting_permissions_date(createDate,accessedDate)
        }
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 76
        }
        return 64
    }
    
}
