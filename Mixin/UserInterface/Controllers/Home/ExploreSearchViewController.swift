import UIKit
import MixinServices

protocol ExploreSearchViewController: SearchNavigationControllerChild {
    var searchTextField: UITextField! { get }
}

extension ExploreSearchViewController where Self: UIViewController {
    
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
    
    var exploreViewController: ExploreViewController? {
        parent?.parent as? ExploreViewController
    }
    
    func pushTokenViewController(token: MixinTokenItem) {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        let viewController = MixinTokenViewController(token: token)
        navigationController.pushViewController(viewController, animated: true)
        AppGroupUserDefaults.User.insertRecentSearch(.mixinToken(assetID: token.assetID))
    }
    
    func pushConversationViewController(userItem: UserItem) {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        let vc = ConversationViewController.instance(ownerUser: userItem)
        navigationController.pushViewController(vc, animated: true)
        AppGroupUserDefaults.User.insertRecentSearch(.app(userID: userItem.userId))
    }
    
    func presentDapp(app: Web3Dapp) {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        let context = MixinWebViewController.Context(conversationId: "", initialUrl: app.homeURL)
        container.presentWebViewController(context: context)
        AppGroupUserDefaults.User.insertRecentSearch(.dapp(name: app.name))
    }
    
}
