import UIKit

class AuthorizationScopesView: UIView {
    
    private var scopes: [AuthorizationScope] = []
    private var dataSource: AuthorizationScopeDataSource!
    
    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = R.color.background_input()
        tableView.allowsMultipleSelection = true
        tableView.separatorStyle = .none
        tableView.isUserInteractionEnabled = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.layer.cornerRadius = 13
        tableView.alwaysBounceVertical = false
        tableView.estimatedRowHeight = 70
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.register(R.nib.authorizationScopeCell)
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(bounds.height)
        }
        return tableView
    }()
    
    func render(scopes: [AuthorizationScope], dataSource: AuthorizationScopeDataSource) {
        self.dataSource = dataSource
        self.scopes = scopes
        tableView.reloadData()
        DispatchQueue.main.async {
            for index in 0..<self.scopes.count {
                if dataSource.isSelected(self.scopes[index]) {
                    self.tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
}

extension AuthorizationScopesView: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        scopes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization_scope_list, for: indexPath)!
        let scope = scopes[indexPath.row]
        cell.render(scope: scope,
                    isSelected: dataSource.isSelected(scope),
                    forceChecked: dataSource.arbitraryScopes.contains(scope))
        return cell
    }
    
}

extension AuthorizationScopesView: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dataSource.select(scopes[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        dataSource.deselect(scopes[indexPath.row])
    }
    
}
