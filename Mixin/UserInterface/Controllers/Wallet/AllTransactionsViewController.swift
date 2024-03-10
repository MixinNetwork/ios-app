import UIKit
import MixinServices

final class AllTransactionsViewController: SafeSnapshotListViewController {
    
    init() {
        super.init(displayFilter: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    class func instance() -> UIViewController {
        let list = AllTransactionsViewController()
        let container = ContainerViewController.instance(viewController: list, title: R.string.localizable.all_transactions())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SafeAPI.allDeposits(queue: .global()) { result in
            guard case .success(let deposits) = result else {
                return
            }
            let entries = DepositEntryDAO.shared.compactEntries()
            let myDeposits = deposits.filter { deposit in
                // `SafeAPI.allDeposits` returns all deposits, whether it's mine or other's
                // Filter with my entries to get my deposits
                entries.contains(where: { (entry) in
                    let isDestinationMatch = entry.destination == deposit.destination
                    let isTagMatch: Bool
                    if entry.tag.isNilOrEmpty && deposit.tag.isNilOrEmpty {
                        isTagMatch = true
                    } else if entry.tag == deposit.tag {
                        isTagMatch = true
                    } else {
                        isTagMatch = false
                    }
                    return isDestinationMatch && isTagMatch
                })
            }
            SafeSnapshotDAO.shared.replaceAllPendingSnapshots(with: myDeposits)
        }
    }
    
}

extension AllTransactionsViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func barRightButtonTappedAction() {
        let filterController = AssetFilterViewController.instance()
        filterController.delegate = self
        present(filterController, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.wallet.ic_filter_large()
    }
    
}

extension AllTransactionsViewController: AssetFilterViewControllerDelegate {
    
    func assetFilterViewController(_ controller: AssetFilterViewController, didApplySort sort: Snapshot.Sort) {
        tableView.setContentOffset(.zero, animated: false)
        reloadData(with: sort)
    }
    
}
