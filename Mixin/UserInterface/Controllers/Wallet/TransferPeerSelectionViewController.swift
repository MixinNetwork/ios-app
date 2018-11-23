import UIKit

class TransferPeerSelectionViewController: PeerSelectionViewController {
    
    var asset: AssetItem!
    
    private let separatorColor = UIColor(rgbValue: 0xF3F3F3)
    
    override var content: PeerSelectionViewController.Content {
        return .transferReceivers
    }
    
    override var allowsMultipleSelection: Bool {
        return false
    }
    
    override var searchBoxViewClass: (UIView & SearchBoxView).Type {
        return LargerSearchBoxView.self
    }
    
    override var tableViewHorizontalMargin: CGFloat {
        return 5
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.separatorLineView.backgroundColor = separatorColor
        searchBoxView.separatorLineView.backgroundColor = separatorColor
        tableView.separatorColor = separatorColor
        tableView.rowHeight = 70
    }
    
    override func work(selections: [Peer]) {
        guard let peer = selections.first else {
            return
        }

        switch peer.item {
        case let .conversation(conversation):
            DispatchQueue.global().async { [weak self] in
                guard let user = UserDAO.shared.getUser(userId: conversation.ownerId) else {
                    return
                }
                DispatchQueue.main.async {
                    self?.transferAction(peer: peer, user: user)
                }
            }
        case let .user(user):
            transferAction(peer: peer, user: user)
        }
    }

    private func transferAction(peer: Peer, user: UserItem) {
        guard let navigationController = navigationController else {
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
