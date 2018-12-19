import UIKit

class TransferAssetSearchController: UISearchController {
    
    let transferAssetSearchBar: UISearchBar = {
        let bar = TransferAssetSearchBar()
        bar.searchBarStyle = .default
        bar.showsCancelButton = false
        bar.setImage(UIImage(named: "ic_search"), for: .search, state: .normal)
        bar.setSearchFieldBackgroundImage(UIImage(named: "Conversation/ic_search_bar_background"), for: .normal)
        bar.setPositionAdjustment(UIOffset(horizontal: 7, vertical: 0), for: .search)
        bar.searchTextPositionAdjustment = UIOffset(horizontal: 6, vertical: 0)
        return bar
    }()
    
    override var searchBar: UISearchBar {
        return transferAssetSearchBar
    }
    
}
