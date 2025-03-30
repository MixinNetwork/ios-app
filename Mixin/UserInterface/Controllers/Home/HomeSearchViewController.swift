import UIKit
import MixinServices

protocol HomeSearchViewController: SearchNavigationControllerChild {
    var searchTextField: UITextField! { get }
}

extension HomeSearchViewController where Self: UIViewController {
    
    var trimmedKeyword: String? {
        guard let text = searchTextField.text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return nil
        } else {
            return trimmed
        }
    }
    
    var homeViewController: HomeViewController? {
        return parent?.parent as? HomeViewController
    }
    
    var homeNavigationController: UINavigationController? {
        return homeViewController?.navigationController
    }
    
    func pushViewController(keyword: String?, result: SearchResult) {
        switch result {
        case let result as UserSearchResult where result.user.isCreatedByMessenger:
            let vc = ConversationViewController.instance(ownerUser: result.user)
            homeNavigationController?.pushViewController(vc, animated: true)
        case let result as ConversationSearchResult:
            let vc = ConversationViewController.instance(conversation: result.conversation)
            homeNavigationController?.pushViewController(vc, animated: true)
        case let result as MessagesWithinConversationSearchResult:
            let vc = SearchConversationViewController()
            vc.load(searchResult: result)
            vc.inheritedKeyword = keyword
            searchNavigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func pushTokenViewController(token: MixinTokenItem, source: String) {
        let viewController = MixinTokenViewController(token: token)
        homeNavigationController?.pushViewController(viewController, animated: true)
        reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": source])
    }
    
}
