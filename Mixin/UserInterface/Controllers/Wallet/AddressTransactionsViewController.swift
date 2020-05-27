import UIKit

class AddressTransactionsViewController: AllTransactionsViewController {

    override var showFilters: Bool {
        return false
    }

    class func instance(asset: String, destination: String, tag: String) -> UIViewController {
        let vc = R.storyboard.wallet.peer_transaction()!
        vc.dataSource = SnapshotDataSource(category: .address(asset: asset, destination: destination, tag: tag))
        let container = ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_TRANSACTIONS)
        container.delegate = nil
        return container
    }
}
