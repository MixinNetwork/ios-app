import UIKit

class AuthorizationScopeTableView: UIView {
    
    private var scopeItems: [Scope.ItemInfo] = []
    private var scopeHandler: AuthorizationScopeHandler!
    
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
        tableView.showsVerticalScrollIndicator = false
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 10))
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 10))
        tableView.register(R.nib.authorizationScopeCell)
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(bounds.height)
        }
        return tableView
    }()
    
    func render(scopeItems: [Scope.ItemInfo], scopeHandler: AuthorizationScopeHandler) {
        self.scopeHandler = scopeHandler
        self.scopeItems = scopeItems
        tableView.reloadData()
        DispatchQueue.main.async {
            for index in 0..<self.scopeItems.count {
                if self.scopeItems[index].isSelected {
                    self.tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
}

extension AuthorizationScopeTableView: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        scopeItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.authorization_scope_list, for: indexPath)!
        let item = scopeItems[indexPath.row]
        cell.render(item: item, forceChecked: item.scope == Scope.PROFILE.rawValue)
        return cell
    }
    
}

extension AuthorizationScopeTableView: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        scopeHandler.select(item: scopeItems[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        scopeHandler.deselect(item: scopeItems[indexPath.row])
    }
    
}
