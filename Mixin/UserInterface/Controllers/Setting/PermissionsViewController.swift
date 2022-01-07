import UIKit
import WebKit
import MixinServices

final class PermissionsViewController: UIViewController {
    
    static let authorizationRevokedNotification = Notification.Name("one.mixin.messenger.PermissionsViewController.authorizationRevoked")
    static let appIdUserInfoKey = "aid"
    
    enum DataSource {
        case app(id: String)
        case response(AuthorizationResponse)
    }
    
    private let iconView = NavigationAvatarIconView()
    private let footerReuseId = "footer"
    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        } else {
            return LayoutMarginsInsetedTableView(frame: .zero, style: .grouped)
        }
    }()
    
    private var dataSource: DataSource?
    
    private var isDataLoaded = false
    private var app: App?
    private var scopes = [(scope: Scope, name: String, desc: String)]()
    private var dateDescription: String?
    
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
        
        switch dataSource {
        case .app(let id):
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            AuthorizeAPI.authorizations(appId: id) { [weak self] result in
                guard let self = self else {
                    return
                }
                switch result {
                case let .success(responses):
                    if let response = responses.first {
                        self.reloadData(response: response)
                        hud.hide()
                    } else {
                        hud.set(style: .error, text: R.string.localizable.setting_no_authorizations())
                        hud.scheduleAutoHidden()
                    }
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        case .response(let authorization):
            reloadData(response: authorization)
        case .none:
            assertionFailure("No data source")
        }
    }
    
    class func instance(dataSource: DataSource) -> UIViewController {
        let vc = PermissionsViewController()
        vc.dataSource = dataSource
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_permissions())
    }
    
    @objc func profileAction() {
        guard let app = app else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            guard let user = UserDAO.shared.getUsers(ofAppIds: [app.appId]).first else {
                return
            }
            DispatchQueue.main.async {
                let vc = UserProfileViewController(user: user)
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    private func reloadData(response: AuthorizationResponse) {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(profileAction))
        iconView.addGestureRecognizer(tapRecognizer)
        iconView.isUserInteractionEnabled = true
        iconView.frame.size = iconView.intrinsicContentSize
        iconView.hasShadow = true
        iconView.setImage(with: response.app.iconUrl,
                          userId: response.app.appId,
                          name: response.app.name)
        container?.navigationBar.addSubview(iconView)
        iconView.snp.makeConstraints { (make) in
            make.centerY.equalTo(container!.rightButton)
            make.right.equalToSuperview().offset(-15)
        }
        
        let createDate = DateFormatter.dateFull.string(from: response.createdAt.toUTCDate())
        let accessedDate = DateFormatter.dateFull.string(from: response.accessedAt.toUTCDate())
        
        app = response.app
        scopes = Scope.getCompleteScopeInfo(authInfo: response).0
        dateDescription = R.string.localizable.setting_permissions_date(createDate, accessedDate)
        isDataLoaded = true
        tableView.reloadData()
    }
    
    private func revoke() {
        guard let app = app else {
            return
        }
        let alert = UIAlertController(title: R.string.localizable.setting_revoke_confirmation(app.name), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CONFIRM, style: .destructive, handler: { (action) in
            AuthorizeAPI.cancel(clientId: app.appId) { [weak self](result) in
                switch result {
                case .success:
                    NotificationCenter.default.post(name: Self.authorizationRevokedNotification,
                                                    object: self,
                                                    userInfo: [Self.appIdUserInfoKey: app.appId])
                    if let appHost = URL(string: app.homeUri)?.host {
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
    
}

// MARK: - UITableViewDataSource
extension PermissionsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        isDataLoaded ? 2 : 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard isDataLoaded else {
            return 0
        }
        if section == 0 {
            return scopes.count
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
            revoke()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SettingsFooterView
        if section == 0, let text = dateDescription {
            view.text = text
        }
        return view
    }
    
}
