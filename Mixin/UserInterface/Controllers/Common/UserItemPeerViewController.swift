import Foundation

class UserItemPeerViewController<CellType: PeerCell>: PeerViewController<UserItem, CellType> {
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [UserItem]) {
        return ([], [])
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            
        }
    }
    
    override func configure(cell: CellType, at indexPath: IndexPath) {
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }
    
}
