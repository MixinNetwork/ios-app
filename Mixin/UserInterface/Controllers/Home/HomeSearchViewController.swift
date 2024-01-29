import UIKit
import MixinServices

enum HomeSearchNotification {
    static let didPushConversationNotification = Notification.Name("one.mixin.messenger.DidPushConversation")
    static let didPushTokenNotification = Notification.Name("one.mixin.messenger.DidPushToken")
    static let assetIDUserInfoKey = "aid"
    static let conversationIDUserInfoKey = "cid"
}

protocol HomeSearchViewController {
    var searchTextField: UITextField! { get }
    var wantsNavigationSearchBox: Bool { get }
    var navigationSearchBoxInsets: UIEdgeInsets { get }
}

extension HomeSearchViewController where Self: UIViewController {
    
    var trimmedLowercaseKeyword: String? {
        guard let text = searchTextField.text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }
        return trimmed.lowercased()
    }
    
    var homeViewController: HomeViewController? {
        return parent?.parent as? HomeViewController
    }
    
    var homeNavigationController: UINavigationController? {
        return homeViewController?.navigationController
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
    
    var navigationSearchBoxView: SearchBoxView! {
        return searchNavigationController?.searchNavigationBar.searchBoxView
    }
    
    var searchTextField: UITextField! {
        return navigationSearchBoxView.textField
    }
    
    func pushViewController(keyword: String?, result: SearchResult) {
        switch result {
        case let result as UserSearchResult where result.user.isCreatedByMessenger:
            let vc = ConversationViewController.instance(ownerUser: result.user)
            homeNavigationController?.pushViewController(vc, animated: true)
            NotificationCenter.default.post(name: HomeSearchNotification.didPushConversationNotification,
                                            object: self,
                                            userInfo: [HomeSearchNotification.conversationIDUserInfoKey: vc.conversationId])
        case let result as ConversationSearchResult:
            let vc = ConversationViewController.instance(conversation: result.conversation)
            homeNavigationController?.pushViewController(vc, animated: true)
            NotificationCenter.default.post(name: HomeSearchNotification.didPushConversationNotification,
                                            object: self,
                                            userInfo: [HomeSearchNotification.conversationIDUserInfoKey: vc.conversationId])
        case let result as MessagesWithinConversationSearchResult:
            let vc = SearchConversationViewController()
            vc.load(searchResult: result)
            vc.inheritedKeyword = keyword
            searchNavigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func pushTokenViewController(token: TokenItem) {
        let viewController = TokenViewController.instance(token: token)
        homeNavigationController?.pushViewController(viewController, animated: true)
        NotificationCenter.default.post(name: HomeSearchNotification.didPushTokenNotification,
                                        object: self,
                                        userInfo: [HomeSearchNotification.assetIDUserInfoKey: token.assetID])
    }
    
}
