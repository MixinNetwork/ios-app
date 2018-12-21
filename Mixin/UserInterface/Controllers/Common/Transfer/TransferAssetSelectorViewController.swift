import UIKit

class TransferAssetSelectorViewController: TransferAssetsDisplayViewController, TransferViewControllerContextAccessible {
    
    private lazy var searchResultsController = TransferAssetSearchResultViewController()
    private lazy var searchController = TransferAssetSearchController(searchResultsController: searchResultsController)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.delegate = self
        navigationItem.titleView = TransferAssetSearchBarContainerView(searchBar: searchController.searchBar)
        definesPresentationContext = true
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        context?.asset = assets[indexPath.row]
        navigationController?.popViewController(animated: true)
    }
    
}

extension TransferAssetSelectorViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
}

extension TransferAssetSelectorViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        var keyword = searchController.searchBar.text ?? ""
        keyword = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        if let vc = searchController.searchResultsController as? TransferAssetSearchResultViewController {
            vc.assets = self.assets.filter({ $0.symbol.lowercased().contains(keyword) })
            vc.tableView.reloadData()
        }
    }
    
}
