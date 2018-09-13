import UIKit

class AuthorizationsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var networkIndicatorTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorView: UIActivityIndicatorView!
    
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
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "authorization")
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_AUTHORIZATIONS)
    }
    
}

extension AuthorizationsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return authorizations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! AuthorizationTableViewCell
        let auth = authorizations[indexPath.row]
        if let url = URL(string: auth.app.iconUrl) {
            cell.iconImageView.sd_setImage(with: url, completed: nil)
        }
        cell.label.text = auth.app.name
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
    
}

extension AuthorizationsViewController {
    
    private func reload() {
        AuthorizeAPI.shared.authorizations { [weak self] (result) in
            switch result {
            case .success(let response):
                self?.load(authorizations: response)
            case .failure(_):
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: {
                    self?.reload()
                })
            }
        }
    }
    
    private func load(authorizations: [AuthorizationResponse]) {
        self.authorizations = authorizations
        tableView.reloadData()
        networkIndicatorView.stopAnimating()
        networkIndicatorTopConstraint.constant = networkIndicatorHeightConstraint.constant
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let auth = authorizations.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        AuthorizeAPI.shared.cancel(clientId: auth.app.appId) { (_) in }
    }
    
}
