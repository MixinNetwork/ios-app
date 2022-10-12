import UIKit

class WalletTransferSearchResultsViewController: WalletSearchResultsViewController {

    weak var transferSearchController: TransferSearchViewController?
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let transferSearchController {
            let asset = searchResults[indexPath.row]
            transferSearchController.delegate?.transferSearchViewController(transferSearchController, didSelectAsset: asset)
            transferSearchController.dismiss(animated: true)
        }
    }
    
}
