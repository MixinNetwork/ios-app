import UIKit
import WebKit
import MixinServices

final class PermissionsViewController: UIViewController {
    
    static let authorizationRevokedNotification = Notification.Name("one.mixin.messenger.PermissionsViewController.authorizationRevoked")
    static let appIdUserInfoKey = "aid"
    
    private let iconView = NavigationAvatarIconView()
    private let footerReuseId = "footer"
    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        } else {
            return LayoutMarginsInsetedTableView(frame: .zero, style: .grouped)
        }
    }()
    
    private var appId: String?
    private var authorization: AuthorizationResponse?
    private var scopes = [(scope: Scope, name: String, desc: String)]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .background
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(R.nib.permissionsTableViewCell)
        tableView.register(R.nib.permissionsActionCell)
        tableView.register(SettingsFooterView.self,
                           forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        
        if let authorization = authorization {
            (scopes, _) = Scope.getCompleteScopeInfo(authInfo: authorization)
            prepareNavigationBar()
        } else if let appId = appId {
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            DispatchQueue.global().async {
                AuthorizeAPI.authorizations(appId: appId) { [weak self] result in
                    DispatchQueue.main.async {
                        hud.hide()
                    }
                    switch result {
                    case let .success(response):
                        if let authorization = response.first {
                            DispatchQueue.main.async {
                                guard let self = self else {
                                    return
                                }
                                self.authorization = authorization
                                self.scopes = Scope.getCompleteScopeInfo(authInfo: authorization).0
                                self.prepareNavigationBar()
                                self.tableView.reloadData()
                            }
                        } else {
                            showAutoHiddenHud(style: .error, text: R.string.localizable.setting_no_authorizations())
                        }
                    case let .failure(error):
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    class func instance(appId: String? = nil, authorization: AuthorizationResponse? = nil) -> UIViewController {
        let vc = PermissionsViewController()
        vc.authorization = authorization
        vc.appId = appId
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_permissions())
    }
    
    @objc func profileAction() {
        guard let appId = authorization?.app.appId else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            guard let user = UserDAO.shared.getUsers(ofAppIds: [appId]).first else {
                return
            }
            DispatchQueue.main.async {
                let vc = UserProfileViewController(user: user)
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    private func removeAuthozationAction() {
        guard let authorization = authorization else {
            return
        }
        let appHomeUri = authorization.app.homeUri
        let appId = authorization.app.appId
        let alert = UIAlertController(title: R.string.localizable.setting_revoke_confirmation(authorization.app.name), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CONFIRM, style: .destructive, handler: { (action) in
            AuthorizeAPI.cancel(clientId: appId) { [weak self](result) in
                switch result {
                case .success:
                    NotificationCenter.default.post(name: Self.authorizationRevokedNotification,
                                                    object: self,
                                                    userInfo: [Self.appIdUserInfoKey: appId])
                    if let appHost = URL(string: appHomeUri)?.host {
                        let dataStore = WKWebsiteDataStore.default()
                        let types = WKWebsiteDataStore.allWebsiteDataTypes()
                        dataStore.fetchDataRecords(ofTypes: types) { (records) in
                            dataStore.removeData(ofTypes: types,
                                                 for: records.filter { appHost.hasSuffix($0.displayName) },
                                                 completionHandler: {})
                        }
                    }
                    self?.navigationController?.popViewController(animated: true)
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func prepareNavigationBar() {
        guard let authorization = authorization else {
            return
        }
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(profileAction))
        iconView.addGestureRecognizer(tapRecognizer)
        iconView.isUserInteractionEnabled = true
        iconView.frame.size = iconView.intrinsicContentSize
        iconView.hasShadow = true
        iconView.setImage(with: authorization.app.iconUrl,
                          userId: authorization.app.appId,
                          name: authorization.app.name)
        container?.navigationBar.addSubview(iconView)
        iconView.snp.makeConstraints { (make) in
            make.centerY.equalTo(container!.rightButton)
            make.right.equalToSuperview().offset(-15)
        }
    }
    
}

// MARK: - UITableViewDataSource
extension PermissionsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let authorization = authorization else {
            return 0
        }
        if section == 0 {
            return authorization.scopes.count
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        func roundCornersIfNeeded(cell: UITableViewCell) {
            let roundTop = indexPath.row == 0
            let roundBottom = indexPath.section == 1 || indexPath.row == scopes.count - 1
            var maskedCorners: CACornerMask = []
            if roundTop {
                maskedCorners.formUnion([.layerMinXMinYCorner, .layerMaxXMinYCorner])
            }
            if roundBottom {
                maskedCorners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
            }
            cell.layer.maskedCorners = maskedCorners
            cell.layer.cornerRadius = (roundTop || roundBottom) ? 10 : 0
        }
        
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.permission, for: indexPath)!
            let scope = scopes[indexPath.row]
            cell.render(name: scope.name, desc: scope.desc)
            roundCornersIfNeeded(cell: cell)
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.permissions_action, for: indexPath)!
            cell.contentLabel.text = R.string.localizable.action_revoke()
            cell.contentLabel.textColor = R.color.red()
            roundCornersIfNeeded(cell: cell)
            return cell
        }
    }
    
}

// MARK: - UITableViewDelegate
extension PermissionsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 76
        } else {
            return 64
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 10 : .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            removeAuthozationAction()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SettingsFooterView
        if section == 0, let authorization = authorization {
            let createDate = DateFormatter.dateFull.string(from: authorization.createdAt.toUTCDate())
            let accessedDate = DateFormatter.dateFull.string(from: authorization.accessedAt.toUTCDate())
            view.text = R.string.localizable.setting_permissions_date(createDate, accessedDate)
        }
        return view
    }
    
}
