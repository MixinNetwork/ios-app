import UIKit

final class PeerTransactionsViewController: SafeSnapshotListViewController {
    
    init(opponentUserID: String) {
        super.init(displayFilter: .user(id: opponentUserID))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    class func instance(opponentId: String) -> UIViewController {
        let controller = PeerTransactionsViewController(opponentUserID: opponentId)
        let container = ContainerViewController.instance(viewController: controller, title: R.string.localizable.transactions())
        return container
    }
    
}
