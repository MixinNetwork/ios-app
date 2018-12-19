import UIKit

class TransferAssetSearchResultViewController: TransferAssetsDisplayViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        if let vc = presentingViewController as? TransferAssetSelectorViewController {
            vc.context?.asset = assets[indexPath.row]
            vc.navigationController?.popViewController(animated: true)
        }
    }
    
}
