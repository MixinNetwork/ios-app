import UIKit

class PeerTransactionsViewController: AllTransactionsViewController {
    
    override var showFilters: Bool {
        return false
    }
    
    class func instance(opponentId: String) -> UIViewController {
        let vc = R.storyboard.wallet.peer_transaction()!
        vc.dataSource = SnapshotDataSource(category: .user(id: opponentId))
        let container = ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_TRANSACTIONS)
        return container
    }
    
}
