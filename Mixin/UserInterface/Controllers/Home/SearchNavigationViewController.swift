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
    
    func pushViewController(keyword: String, result: SearchResult) {
        switch result.target {
        case let .contact(user):
            let vc = ConversationViewController.instance(ownerUser: user)
            parent?.navigationController?.pushViewController(vc, animated: true)
        case let .group(conversation):
            let vc = ConversationViewController.instance(conversation: conversation)
            parent?.navigationController?.pushViewController(vc, animated: true)
        case .searchMessageWithContact, .searchMessageWithGroup:
            let vc = R.storyboard.home.search_conversation()!
            vc.load(searchResult: result)
            vc.inheritedKeyword = keyword
            pushViewController(vc, animated: true)
        case .message:
            assertionFailure()
        }
    }
    
}
