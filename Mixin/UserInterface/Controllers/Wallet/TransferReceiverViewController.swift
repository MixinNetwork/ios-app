import UIKit
import MixinServices

class TransferReceiverViewController: UserItemPeerViewController<PeerCell> {
    
    private var asset: TokenItem!
    
    class func instance(asset: TokenItem) -> UIViewController {
        let vc = TransferReceiverViewController()
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.send_to_title())
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
        cell.peerInfoViewLeadingConstraint.constant = 36
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let navigationController = navigationController else {
            return
        }
        let user = self.user(at: indexPath)
        let transfer = TransferOutViewController(token: asset, to: .contact(user))
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.lastIndex(where: { ($0 as? ContainerViewController)?.viewController == self }) {
            viewControllers.remove(at: index)
        }
        viewControllers.append(transfer)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
}
