import UIKit
import MixinServices

final class PermissionsViewController: UIViewController {
    
    private let iconView = NavigationAvatarIconView()
    private let footerReuseId = "footer"
    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        } else {
            return LayoutMarginsInsetedTableView(frame: .zero, style: .grouped)
        }
    }()
    
    private var authorization: AuthorizationResponse!
    private var scopes = [(scope: Scope, name: String, desc: String)]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (scopes, _) = Scope.getCompleteScopeInfo(authInfo: authorization)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .background
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(R.nib.permissionsTableViewCell)
        tableView.register(R.nib.permissionsActionCell)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        prepareNavigationBar()
    }
    
    class func instance(authorization: AuthorizationResponse) -> UIViewController {
        let vc = PermissionsViewController()
        vc.authorization = authorization
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_permissions())
    }
    
    @objc func profileAction() {
        let appId = authorization.app.appId
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
    
    private func prepareNavigationBar() {
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
            cell.contentLabel.text = R.string.localizable.action_deauthorize()
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
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        view.backgroundView?.backgroundColor = .background
        view.contentView.backgroundColor = .background
        view.shadowView.isHidden = true
        if section == 0 {
            let createDate = DateFormatter.dateFull.string(from: authorization.createdAt.toUTCDate())
            let accessedDate = DateFormatter.dateFull.string(from: authorization.accessedAt.toUTCDate())
            view.text = R.string.localizable.setting_permissions_date(createDate, accessedDate)
        }
        return view
    }
    
}
