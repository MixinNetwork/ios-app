import UIKit

class SearchNavigationBar: UINavigationBar {
    
    let searchBoxView = SearchBoxView(frame: CGRect(x: 0, y: 0, width: 375, height: 40))
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addSubview(searchBoxView)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(searchBoxView)
    }
    
    func layoutSearchBoxView(insets: UIEdgeInsets) {
        searchBoxView.frame = CGRect(x: insets.left,
                                     y: (bounds.height - searchBoxView.frame.height) / 2,
                                     width: bounds.width - insets.horizontal,
                                     height: searchBoxView.frame.height)
        layoutIfNeeded()
    }
    
}
