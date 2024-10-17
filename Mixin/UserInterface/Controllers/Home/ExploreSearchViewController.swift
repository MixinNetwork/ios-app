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
    
    func pushMarketViewController(market: FavorableMarket) {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        let viewController = MarketViewController.contained(market: market, pushingViewController: self)
        navigationController.pushViewController(viewController, animated: true)
        AppGroupUserDefaults.User.insertRecentSearch(.market(coinID: market.coinID))
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
        guard let container = UIApplication.homeContainerViewController?.homeTabBarController else {
            return
        }
        let context = MixinWebViewController.Context(conversationId: "", initialUrl: app.homeURL)
        MixinWebViewController.presentInstance(with: context, asChildOf: container)
        AppGroupUserDefaults.User.insertRecentSearch(.dapp(name: app.name))
    }
    
}
