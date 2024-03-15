import UIKit
import MixinServices

final class PeerTransactionsViewController: SafeSnapshotListViewController {
    
    private lazy var filterController = SnapshotFilterViewController(sort: .createdAt)
    
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

extension PeerTransactionsViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        filterController.delegate = self
        present(filterController, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.wallet.ic_filter_large()
    }
    
}

extension PeerTransactionsViewController: SnapshotFilterViewController.Delegate {
    
    func snapshotFilterViewController(_ controller: SnapshotFilterViewController, didApplySort sort: Snapshot.Sort) {
        tableView.setContentOffset(.zero, animated: false)
        reloadData(with: sort)
    }
    
}
