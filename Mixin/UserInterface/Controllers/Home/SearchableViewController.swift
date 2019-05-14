import UIKit

protocol SearchableViewController {
    var searchTextField: UITextField { get }
    var wantsNavigationSearchBox: Bool { get }
    var navigationSearchBoxInsets: UIEdgeInsets { get }
}

extension SearchableViewController where Self: UIViewController {
    
    var keyword: Keyword? {
        return Keyword(raw: searchTextField.text)
    }
    
    var homeNavigationController: UINavigationController? {
        assert(parent?.parent is HomeViewController)
        return parent?.parent?.navigationController
    }
    
    var searchNavigationController: SearchNavigationViewController? {
        return navigationController as? SearchNavigationViewController
    }
    
    var cancelButtonRightMargin: CGFloat {
        return 20
    }
    
    var backButtonWidth: CGFloat {
        return 54
    }
    
    var navigationSearchBoxView: SearchBoxView {
        return searchNavigationController!.searchNavigationBar.searchBoxView
    }
    
    var searchTextField: UITextField {
        return navigationSearchBoxView.textField
    }
    
    func pushViewController(keyword: Keyword?, result: SearchResult) {
        switch result {
        case let result as UserSearchResult:
            let vc = ConversationViewController.instance(ownerUser: result.user)
            homeNavigationController?.pushViewController(vc, animated: true)
        case let result as ConversationSearchResult:
            let vc = ConversationViewController.instance(conversation: result.conversation)
            homeNavigationController?.pushViewController(vc, animated: true)
        case let result as MessagesWithinConversationSearchResult:
            let vc = R.storyboard.home.search_conversation()!
            vc.load(searchResult: result)
            vc.inheritedKeyword = keyword
            searchNavigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func pushAssetViewController(asset: AssetItem) {
        let vc = AssetViewController.instance(asset: asset)
        homeNavigationController?.pushViewController(vc, animated: true)
    }
    
}
