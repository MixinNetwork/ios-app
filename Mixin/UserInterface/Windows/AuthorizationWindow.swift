import Foundation
import MixinServices

class AuthorizationWindow: BottomSheetView {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var iconImageView: CornerImageView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var authorizeButton: RoundedButton!
    @IBOutlet weak var titleLabel: UILabel!

    private var authInfo: AuthorizationResponse!
    private var assets: [AssetItem] = []
    private var loginSuccess = false

    private enum Scope: String {
        case PROFILE = "PROFILE:READ"
        case PHONE = "PHONE:READ"
        case ASSETS = "ASSETS:READ"
        case APPS_READ = "APPS:READ"
        case APPS_WRITE = "APPS:WRITE"
        case CONTACTS_READ = "CONTACTS:READ"
        case MESSAGES_REPRESENT = "MESSAGES:REPRESENT"
        case SNAPSHOTS_READ = "SNAPSHOTS:READ"
    }
    private lazy var scopes: [(scope: Scope, name: String, desc: String)] = {
        guard let account = LoginManager.shared.account else {
            return []
        }
        var result = [(scope: Scope, name: String, desc: String)]()
        result.append((.PROFILE, Localized.AUTH_PERMISSION_PROFILE, Localized.AUTH_PROFILE_DESCRIPTION(fullName: account.full_name, phone: account.identity_number)))

        if authInfo.scopes.contains(Scope.PHONE.rawValue) {
            result.append((.PHONE, Localized.AUTH_PERMISSION_PHONE, account.phone))
            selectedScopes.append(Scope.PHONE.rawValue)
        }
        if authInfo.scopes.contains(Scope.MESSAGES_REPRESENT.rawValue) {
            result.append((.APPS_WRITE, R.string.localizable.auth_permission_messages_represent(), R.string.localizable.auth_permission_messages_represent_description()))
            selectedScopes.append(Scope.MESSAGES_REPRESENT.rawValue)
        }
        if authInfo.scopes.contains(Scope.CONTACTS_READ.rawValue) {
            result.append((.APPS_READ, Localized.AUTH_PERMISSION_CONTACTS_READ, Localized.AUTH_PERMISSION_CONTACTS_READ_DESCRIPTION))
            selectedScopes.append(Scope.CONTACTS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.ASSETS.rawValue) {
            result.append((.ASSETS, Localized.AUTH_PERMISSION_ASSETS, getAssetsBalanceText()))
            selectedScopes.append(Scope.ASSETS.rawValue)
        }
        if authInfo.scopes.contains(Scope.SNAPSHOTS_READ.rawValue) {
            result.append((.SNAPSHOTS_READ, R.string.localizable.auth_permission_snapshots_read(), R.string.localizable.auth_permission_snapshots_read_description()))
            selectedScopes.append(Scope.SNAPSHOTS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.APPS_READ.rawValue) {
            result.append((.APPS_READ, Localized.AUTH_PERMISSION_APPS_READ, Localized.AUTH_PERMISSION_APPS_READ_DESCRIPTION))
            selectedScopes.append(Scope.APPS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.APPS_WRITE.rawValue) {
            result.append((.APPS_WRITE, Localized.AUTH_PERMISSION_APPS_WRITE, Localized.AUTH_PERMISSION_APPS_WRITE_DESCRIPTION))
            selectedScopes.append(Scope.APPS_WRITE.rawValue)
        }
        return result
    }()
    private var selectedScopes = [Scope.PROFILE.rawValue]

    func render(authInfo: AuthorizationResponse, assets: [AssetItem]) -> AuthorizationWindow {
        self.authInfo = authInfo
        self.assets = assets

        titleLabel.text = authInfo.app.name
        iconImageView.sd_setImage(with: URL(string: authInfo.app.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))

        prepareTableView()
        tableView.reloadData()
        DispatchQueue.main.async {
            for idx in 0..<self.scopes.count {
                self.tableView.selectRow(at: IndexPath(row: idx, section: 0), animated: false, scrollPosition: .none)
            }
        }
        return self
    }

    override func dismissPopupControllerAnimated() {
        super.dismissPopupControllerAnimated()

        guard !loginSuccess else {
            return
        }

        let request = AuthorizationRequest(authorizationId: authInfo.authorizationId, scopes: [])
        AuthorizeAPI.shared.authorize(authorization: request) { (result) in
            switch result {
            case let .success(response):
                UIApplication.shared.tryOpenThirdApp(response: response)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }

    @IBAction func backAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    @IBAction func authorizeAction(_ sender: Any) {
        guard !authorizeButton.isBusy else {
            return
        }
        authorizeButton.isBusy = true
        let request = AuthorizationRequest(authorizationId: authInfo.authorizationId, scopes: selectedScopes)
        AuthorizeAPI.shared.authorize(authorization: request, completion: { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(response):
                weakSelf.loginSuccess = true
                showAutoHiddenHud(style: .notification, text: Localized.TOAST_AUTHORIZED)
                weakSelf.dismissPopupControllerAnimated()
                if UIApplication.homeNavigationController?.viewControllers.last is CameraViewController {
                    UIApplication.homeNavigationController?.popViewController(animated: true)
                }
                UIApplication.shared.tryOpenThirdApp(response: response)
            case let .failure(error):
                weakSelf.authorizeButton.isBusy = false
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        })
    }

    private func getAssetsBalanceText() -> String {
        guard assets.count > 0 else {
            return "0"
        }
        var result = "\(assets[0].localizedBalance) \(assets[0].symbol)"
        if assets.count > 1 {
            result += ", \(assets[1].localizedBalance) \(assets[1].symbol)"
        }
        if assets.count > 2 {
            result += Localized.AUTH_ASSETS_MORE
        }
        return result
    }

    class func instance() -> AuthorizationWindow {
        return Bundle.main.loadNibNamed("AuthorizationWindow", owner: nil, options: nil)?.first as! AuthorizationWindow
    }
}

extension AuthorizationWindow: UITableViewDelegate, UITableViewDataSource {

    private func prepareTableView() {
        tableView.register(UINib(nibName: "AuthorizationScopeCell", bundle: nil), forCellReuseIdentifier: AuthorizationScopeCell.cellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scopes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AuthorizationScopeCell.cellIdentifier) as! AuthorizationScopeCell
        let scope = scopes[indexPath.row]
        cell.render(name: scope.name, desc: scope.desc)
        if selectedScopes.contains(scope.scope.rawValue) {
            cell.setSelected(true, animated: false)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let scope = scopes[indexPath.row]
        guard !selectedScopes.contains(scope.scope.rawValue) else {
            return
        }

        selectedScopes.append(scope.scope.rawValue)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let scope = scopes[indexPath.row]
        guard let idx = selectedScopes.firstIndex(of: scope.scope.rawValue) else {
            return
        }

        selectedScopes.remove(at: idx)
    }
}

private extension UIApplication {

    func tryOpenThirdApp(response: AuthorizationResponse) {
        let callback = response.app.redirectUri
        guard !callback.isEmpty, let url = URL(string: callback), let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https", var components = URLComponents(string: callback) else {
            return
        }

        if components.queryItems == nil {
            components.queryItems = []
        }
        if response.authorizationCode.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "error", value: "access_denied"))
        } else {
            components.queryItems?.append(URLQueryItem(name: "code", value: response.authorizationCode))
        }

        guard let targetUrl = components.url else {
            return
        }
        UIApplication.shared.open(targetUrl, options: [:], completionHandler: nil)
    }

}
