import UIKit
import MixinServices

final class TransferReceiverViewController: UserItemPeerViewController<PeerCell> {
    
    var onSelect: ((UserItem) -> Void)?
    
    init() {
        let nib = R.nib.peerView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [UserItem]) {
        let transferReceiver = users.filter({ (user) -> Bool in
            if user.isBot {
                return user.appCreatorId == myUserId
            } else {
                return true
            }
        })
        return ([], transferReceiver)
    }
    
    override func configure(cell: PeerCell, at indexPath: IndexPath) {
        super.configure(cell: cell, at: indexPath)
        cell.peerInfoViewLeadingConstraint?.constant = 36
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = self.user(at: indexPath)
        onSelect?(user)
    }
    
}
