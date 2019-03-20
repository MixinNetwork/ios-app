import UIKit

class SendContactSelectionViewController: PeerSelectionViewController {
    
    var asset: AssetItem!
    
    override var content: PeerSelectionViewController.Content {
        return .transferReceivers
    }
    
    override var allowsMultipleSelection: Bool {
        return false
    }

    override var tableRowHeight: CGFloat {
        return 80
    }

    override func loadView() {
        super.loadView()
        searchBoxView.textField.placeholder = Localized.SEARCH_PLACEHOLDER_PARTICIPANTS
    }
    
    override func work(selections: [Peer]) {
        guard let peer = selections.first, let user = peer.user, let navigationController = navigationController else {
            return
        }
        let vc = SendViewController.instance(asset: asset, type: .contact(user))
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.lastIndex(where: { ($0 as? ContainerViewController)?.viewController == self }) {
            viewControllers.remove(at: index)
        }
        viewControllers.append(vc)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = SendContactSelectionViewController()
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: Localized.ACTION_SEND_TO)
    }
    
}
