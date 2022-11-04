import UIKit

class AuthorizationScopesTableView: UITableView {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateProperties()
    }
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        updateProperties()
    }
    
    private func updateProperties() {
        layer.cornerRadius = 13
        clipsToBounds = true
        backgroundColor = R.color.background_input()
        separatorStyle = .none
        alwaysBounceVertical = false
        estimatedRowHeight = 70
        tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        register(R.nib.authorizationScopeCell)
    }
    
}
