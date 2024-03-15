import UIKit

final class AddressTransactionsViewController: SafeSnapshotListViewController {
    
    private let assetID: String
    private let address: String
    
    init(assetID: String, address: String) {
        self.assetID = assetID
        self.address = address
        super.init(displayFilter: .address(assetID: assetID, address: address))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    class func instance(assetID: String, address: String) -> UIViewController {
        let list = AddressTransactionsViewController(assetID: assetID, address: address)
        let container = ContainerViewController.instance(viewController: list, title: R.string.localizable.transactions())
        return container
    }
    
}
