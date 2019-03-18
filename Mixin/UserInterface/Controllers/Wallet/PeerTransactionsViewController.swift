import UIKit

class PeerTransactionsViewController: AllTransactionsViewController {

    class func instance(opponentId: String) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "peer_transaction") as! PeerTransactionsViewController
        vc.dataSource = SnapshotDataSource(category: .user(id: opponentId))
        let container = ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_TRANSACTIONS)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }

}
