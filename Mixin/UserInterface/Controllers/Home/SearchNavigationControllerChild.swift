import UIKit

protocol SearchNavigationControllerChild {
    var wantsNavigationSearchBox: Bool { get }
    var navigationSearchBoxInsets: UIEdgeInsets { get }
}

extension SearchNavigationControllerChild where Self: UIViewController {
    
    var searchNavigationController: SearchNavigationViewController? {
        navigationController as? SearchNavigationViewController
    }
    
    var cancelButtonRightMargin: CGFloat {
        20
    }
    
    var backButtonWidth: CGFloat {
        54
    }
    
    var navigationSearchBoxView: SearchBoxView! {
        searchNavigationController?.searchNavigationBar.searchBoxView
    }
    
    var searchTextField: UITextField! {
        navigationSearchBoxView.textField
    }
    
}
