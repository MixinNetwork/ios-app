import Foundation

class UserItemPeerViewController<CellType: PeerCell>: PeerViewController<UserItem, CellType> {
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [UserItem]) {
        return ([], users)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let users = self.models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let searchResult = users
                .filter({ $0.matches(lowercasedKeyword: keyword) })
                .map({ SearchResult(user: $0, keyword: keyword) })
            DispatchQueue.main.sync {
                guard let weakSelf = self, !op.isCancelled else {
                    return
                }
                weakSelf.searchingKeyword = keyword
                weakSelf.searchResults = searchResult
                weakSelf.tableView.reloadData()
                weakSelf.reloadTableViewSelections()
            }
        }
        queue.addOperation(op)
    }
    
    override func configure(cell: CellType, at indexPath: IndexPath) {
        if isSearching {
            cell.render(result: searchResults[indexPath.row])
        } else {
            cell.render(user: models[indexPath.row])
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : models.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func user(at indexPath: IndexPath) -> UserItem? {
        if isSearching {
            guard case let .contact(user) = searchResults[indexPath.row].target else {
                return nil
            }
            return user
        } else {
            return models[indexPath.row]
        }
    }
    
}
