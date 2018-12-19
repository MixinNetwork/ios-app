import UIKit

class TransferAssetSearchBarContainerView: UIView {
    
    let height: CGFloat = 44
    let searchBarInset = UIEdgeInsets(top: 0, left: -16, bottom: 0, right: -8)
    let searchBar: UISearchBar
    
    init(searchBar: UISearchBar) {
        self.searchBar = searchBar
        let frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height)
        super.init(frame: frame)
        addSubview(searchBar)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        searchBar.frame = bounds.inset(by: searchBarInset)
    }
    
}
