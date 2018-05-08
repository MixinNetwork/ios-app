import UIKit
import SwiftMessages

class LoginView: UIView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var iconImageView: CornerImageView!
    @IBOutlet weak var authButton: StateResponsiveButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var zoomButton: UIButton!

    @IBOutlet weak var iconTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconBottomConstaint: NSLayoutConstraint!

    private weak var superView: UrlWindow?
    private var authInfo: AuthorizationResponse!
    private var assets: [AssetItem] = []
    private var windowMaximum = false
    private var minimumWebViewHeight: CGFloat = 484
    private var loginSuccess = false

    private enum Scope: String {
        case PROFILE = "PROFILE:READ"
        case PHONE = "PHONE:READ"
        case ASSETS = "ASSETS:READ"
        case APPS_READ = "APPS:READ"
        case APPS_WRITE = "APPS:WRITE"
    }
    private lazy var scopes: [(scope: Scope, name: String, desc: String)] = {
        guard let account = AccountAPI.shared.account else {
            return []
        }
        var result = [(scope: Scope, name: String, desc: String)]()
        result.append((.PROFILE, Localized.AUTH_PERMISSION_PROFILE, Localized.AUTH_PROFILE_DESCRIPTION(fullName: account.full_name, phone: account.identity_number)))

        if authInfo.scopes.contains(Scope.PHONE.rawValue) {
            result.append((.PHONE, Localized.AUTH_PERMISSION_PHONE, account.phone))
        }
        if authInfo.scopes.contains(Scope.ASSETS.rawValue) {
            result.append((.ASSETS, Localized.AUTH_PERMISSION_ASSETS, getAssetsBalanceText()))
        }
        if authInfo.scopes.contains(Scope.APPS_READ.rawValue) {
            result.append((.APPS_READ, Localized.AUTH_PERMISSION_APPS_READ, Localized.AUTH_PERMISSION_APPS_READ_DESCRIPTION))
        }
        if authInfo.scopes.contains(Scope.APPS_WRITE.rawValue) {
            result.append((.APPS_WRITE, Localized.AUTH_PERMISSION_APPS_WRITE, Localized.AUTH_PERMISSION_APPS_WRITE_DESCRIPTION))
        }
        return result
    }()
    private var selectedScopes = [Scope.PROFILE.rawValue, Scope.PHONE.rawValue, Scope.ASSETS.rawValue, Scope.APPS_READ.rawValue, Scope.APPS_WRITE.rawValue]

    override func awakeFromNib() {
        super.awakeFromNib()
        authButton.activityIndicator.activityIndicatorViewStyle = .white
    }

    func render(authInfo: AuthorizationResponse, assets: [AssetItem], superView: UrlWindow) {
        self.authInfo = authInfo
        self.assets = assets
        self.superView = superView
        if !superView.fromWeb {
            closeButton.setImage(#imageLiteral(resourceName: "ic_titlebar_close"), for: .normal)
        }

        titleLabel.text = authInfo.app.name
        iconImageView.sd_setImage(with: URL(string: authInfo.app.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))

        prepareTableView()
        tableView.reloadData()
        windowMaximum = superView.contentHeightConstraint.constant > minimumWebViewHeight
        zoomButton.setImage(windowMaximum ? #imageLiteral(resourceName: "ic_titlebar_min") : #imageLiteral(resourceName: "ic_titlebar_max"), for: .normal)
        DispatchQueue.main.async {
            for idx in 0..<self.scopes.count {
                self.tableView.selectRow(at: IndexPath(row: idx, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }

    @IBAction func zoomAction(_ sender: Any) {
        guard let superView = self.superView else {
            return
        }
        windowMaximum = !windowMaximum
        zoomButton.setImage(windowMaximum ? #imageLiteral(resourceName: "ic_titlebar_min") : #imageLiteral(resourceName: "ic_titlebar_max"), for: .normal)

        let oldHeight = superView.contentHeightConstraint.constant
        let targetHeight: CGFloat
        if #available(iOS 11.0, *) {
            targetHeight = windowMaximum ? superView.frame.height - max(safeAreaInsets.top, 20) - safeAreaInsets.bottom : minimumWebViewHeight
        } else {
            targetHeight = windowMaximum ? superView.frame.height - 20 : minimumWebViewHeight
        }
        let scale = targetHeight / oldHeight

        iconTopConstraint.constant = iconTopConstraint.constant * scale
        iconBottomConstaint.constant = iconBottomConstaint.constant * scale
        superView.contentHeightConstraint.constant = targetHeight
        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
            superView.layoutIfNeeded()
        }
    }

    func onWindowWillDismiss() {
        guard !loginSuccess else {
            return
        }

        let request = AuthorizationRequest(authorizationId: authInfo.authorizationId, scopes: [])
        AuthorizeAPI.shared.authorize(authorization: request) { (_) in

        }
    }

    @IBAction func backAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    @IBAction func confirmAction(_ sender: Any) {
        guard !authButton.isBusy else {
            return
        }
        authButton.isBusy = true
        let request = AuthorizationRequest(authorizationId: authInfo.authorizationId, scopes: selectedScopes)
        AuthorizeAPI.shared.authorize(authorization: request, completion: { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success:
                weakSelf.loginSuccess = true
                weakSelf.superView?.dismissPopupControllerAnimated()
                if UIApplication.rootNavigationController()?.viewControllers.last is CameraViewController {
                    UIApplication.rootNavigationController()?.popViewController(animated: true)
                }
            case let .failure(error, _):
                weakSelf.authButton.isBusy = false
                SwiftMessages.showToast(message: error.kind.localizedDescription ?? error.description, backgroundColor: .hintRed)
            }
        })
    }

    private func getAssetsBalanceText() -> String {
        guard assets.count > 0 else {
            return "0"
        }
        var result = "\(assets[0].balance) \(assets[0].symbol)"
        if assets.count > 1 {
            result += ", \(assets[1].balance) \(assets[1].symbol)"
        }
        if assets.count > 2 {
            result += Localized.AUTH_ASSETS_MORE
        }
        return result
    }

    class func instance() -> LoginView {
        return Bundle.main.loadNibNamed("LoginView", owner: nil, options: nil)?.first as! LoginView
    }
}

extension LoginView: UITableViewDelegate, UITableViewDataSource {

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
        guard let idx = selectedScopes.index(of: scope.scope.rawValue) else {
            return
        }

        selectedScopes.remove(at: idx)
    }
}
