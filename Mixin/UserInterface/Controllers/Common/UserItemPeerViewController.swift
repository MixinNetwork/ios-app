import Foundation
import MixinServices

class UserItemPeerViewController<CellType: PeerCell>: PeerViewController<UserItem, CellType, UserSearchResult> {
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [UserItem]) {
        return ([], users)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = SearchOperation(viewController: self, keyword: keyword)
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
    
    func user(at indexPath: IndexPath) -> UserItem {
        if isSearching {
            return searchResults[indexPath.row].user
        } else {
            return models[indexPath.row]
        }
    }
    
    class SearchOperation: Operation {
        
        weak var viewController: UserItemPeerViewController?
        
        let users: [UserItem]
        let keyword: String
        
        init(viewController: UserItemPeerViewController, keyword: String) {
            self.viewController = viewController
            self.users = viewController.models
            self.keyword = keyword
        }
        
        override func main() {
            guard viewController != nil, !isCancelled else {
                return
            }
            let searchResult = users
                .filter({ $0.matches(lowercasedKeyword: keyword) })
                .map({ UserSearchResult(user: $0, keyword: keyword) })
            DispatchQueue.main.sync {
                guard let viewController = viewController, !isCancelled else {
                    return
                }
                viewController.searchingKeyword = keyword
                viewController.searchResults = searchResult
                viewController.tableView.reloadData()
                viewController.reloadTableViewSelections()
            }
        }
        
    }
    
}
