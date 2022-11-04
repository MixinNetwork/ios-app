import UIKit
import MixinServices

protocol AuthorizationScopeConfirmationViewDelegate: AnyObject {
    
    func authorizationScopeConfirmationView(_ view: AuthorizationScopeConfirmationView, didConfirmWith pin: String)
    
}

class AuthorizationScopeConfirmationView: UIView, XibDesignable {
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var numberPadView: NumberPadView!
    @IBOutlet weak var tableView: AuthorizationScopesTableView!
    @IBOutlet weak var loadingIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var tableViewContentHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: AuthorizationScopeConfirmationViewDelegate?
    
    var dataSource: AuthorizationScopeDataSource? {
        didSet {
            tableView.reloadData()
            tableView.layoutIfNeeded()
            tableViewContentHeightConstraint.constant = tableView.contentSize.height
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    @IBAction func pinEditingChangedAction(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        isUserInteractionEnabled = false
        loadingIndicator.startAnimating()
        pinField.isHidden = true
        pinField.receivesInput = false
        delegate?.authorizationScopeConfirmationView(self, didConfirmWith: pinField.text)
    }
    
    func resetInput() {
        pinField.clear()
        pinField.isHidden = false
        pinField.receivesInput = true
        isUserInteractionEnabled = true
    }
    
    private func loadSubviews() {
        loadXib()
        tableView.dataSource = self
        tableView.delegate = self
        numberPadView.target = pinField
    }
    
}

extension AuthorizationScopeConfirmationView: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataSource?.pendingConfirmationScopes.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization_scope_list, for: indexPath)!
        guard let dataSource else {
            return cell
        }
        let scope = dataSource.pendingConfirmationScopes[indexPath.row]
        cell.titleLabel.text = scope.title
        cell.descriptionLabel.text = scope.description
        if dataSource.arbitraryScopes.contains(scope) {
            cell.checkmarkView.status = .nonSelectable
        } else if dataSource.confirmedScopes.contains(scope) {
            cell.checkmarkView.status = .selected
        } else {
            cell.checkmarkView.status = .deselected
        }
        return cell
    }
    
}

extension AuthorizationScopeConfirmationView: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dataSource, let cell = tableView.cellForRow(at: indexPath) as? AuthorizationScopeCell else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)
        let scope = dataSource.pendingConfirmationScopes[indexPath.row]
        let wasSelected = dataSource.isScope(scope, selectedBy: .confirmation)
        if wasSelected {
            if dataSource.deselect(scope: scope, by: .confirmation) {
                cell.checkmarkView.status = .deselected
            }
        } else {
            dataSource.select(scope: scope, by: .confirmation)
            cell.checkmarkView.status = .selected
        }
    }
    
}
