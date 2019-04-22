import UIKit

class SearchNavigationViewController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let image = UIColor.white.image
        navigationBar.setBackgroundImage(image, for: .default)
        navigationBar.shadowImage = image
        navigationBar.backIndicatorImage = R.image.ic_search_back()
        navigationBar.backIndicatorTransitionMaskImage = R.image.ic_search_back()
    }
    
    func pushViewController(keyword: String, result: ConversationSearchResult) {
        switch result.target {
        case let .contact(user):
            let vc = ConversationViewController.instance(ownerUser: user)
            parent?.navigationController?.pushViewController(vc, animated: true)
        case let .group(conversation):
            let vc = ConversationViewController.instance(conversation: conversation)
            parent?.navigationController?.pushViewController(vc, animated: true)
        case let .searchMessageWithContact(_, conversationId):
            let vc = R.storyboard.home.search_conversation()!
            vc.conversationId = conversationId
            vc.keyword = keyword
            pushViewController(vc, animated: true)
        case let .searchMessageWithGroup(conversationId):
            let vc = R.storyboard.home.search_conversation()!
            vc.conversationId = conversationId
            vc.keyword = keyword
            pushViewController(vc, animated: true)
        }
    }
    
}
