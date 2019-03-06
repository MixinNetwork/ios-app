import UIKit

class SendContactSelectionViewController: PeerSelectionViewController {
    
    override class var usesModernStyle: Bool {
        return false
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
        return ContainerViewController.instance(viewController: vc, title: Localized.TRANSFER_TITLE_TO)
    }
    
}
