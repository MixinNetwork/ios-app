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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let permissionvc = PermissionsViewController.instance(authorization: authorizations[indexPath.row])
        self.navigationController?.pushViewController(permissionvc, animated: true)
    }
    
}

extension AuthorizationsViewController {
    
    private func reload() {
        AuthorizeAPI.authorizations { [weak self] (result) in
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
                             photo: R.image.emptyIndicator.ic_authorization()!)
    }
    
}
