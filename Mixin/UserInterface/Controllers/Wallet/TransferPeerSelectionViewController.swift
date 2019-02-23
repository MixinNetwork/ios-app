import UIKit

class TransferPeerSelectionViewController: PeerSelectionViewController {
    
    override class var usesModernStyle: Bool {
        return true
    }
    
    var asset: AssetItem!
    
    private let separatorColor = UIColor(rgbValue: 0xF3F3F3)
    
    override var content: PeerSelectionViewController.Content {
        return .transferReceivers
    }
    
    override var allowsMultipleSelection: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorColor = separatorColor
        tableView.rowHeight = 70
    }
    
    override func work(selections: [Peer]) {
        guard let peer = selections.first, let user = peer.user, let navigationController = navigationController else {
            return
        }
        let vc = TransferViewController.instance(user: user,
                                                 conversationId: peer.conversationId,
                                                 asset: asset,
                                                 usePresentAnimationWhenPushed: false)
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.lastIndex(where: { ($0 as? ContainerViewController)?.viewController == self }) {
            viewControllers.remove(at: index)
        }
        viewControllers.append(vc)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = TransferPeerSelectionViewController()
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: Localized.TRANSFER_TITLE_TO)
    }
    
}
