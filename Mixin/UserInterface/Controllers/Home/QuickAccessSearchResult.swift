import Foundation
import Alamofire
import MixinServices

final class QuickAccessSearchResult {
    
    enum Content {
        case number(String)
        case link(url: URL, verbatim: String)
    }
    
    private static let idOrPhoneCharacterSet = Set("+0123456789")
    
    let content: Content
    
    @Published private(set) var isBusy: Bool = false
    
    private var searchNumberRequest: Request? {
        didSet {
            isBusy = searchNumberRequest != nil
        }
    }
    
    init?(keyword: String) {
        let number: String? = {
            guard keyword.count >= 4 else {
                return nil
            }
            guard Self.idOrPhoneCharacterSet.isSuperset(of: keyword) else {
                return nil
            }
            if keyword.contains("+") {
                if PhoneNumberValidator.global.isValid(keyword) {
                    return keyword
                } else {
                    return nil
                }
            } else {
                return keyword
            }
        }()
        
        let link: (URL, String)? = {
            var link: (URL, String)?
            Link.detector.enumerateMatches(in: keyword, options: []) { match, _, stop in
                guard let match = match, let url = match.url else {
                    return
                }
                let verbatim = (keyword as NSString).substring(with: match.range)
                link = (url, verbatim)
                stop.pointee = ObjCBool(true)
            }
            return link
        }()
        
        if keyword.isEmpty {
            return nil
        } else if let number = number {
            self.content = .number(number)
        } else if let link = link {
            self.content = .link(url: link.0, verbatim: link.1)
        } else {
            return nil
        }
    }
    
    func performQuickAccess(completion: @escaping (UserItem?) -> Void) {
        switch content {
        case let .number(number):
            searchNumberRequest = UserAPI.search(keyword: number) { [weak self] (result) in
                switch result {
                case let .success(user):
                    UserDAO.shared.updateUsers(users: [user])
                    let userItem = UserItem.createUser(from: user)
                    if userItem.isCreatedByMessenger {
                        completion(userItem)
                    } else {
                        completion(nil)
                    }
                case let .failure(error):
                    let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.user_not_found())
                    showAutoHiddenHud(style: .error, text: text)
                    completion(nil)
                }
                self?.searchNumberRequest = nil
            }
        case let .link(url, _):
            let isOpened = UrlWindow.checkUrl(url: url)
            if !isOpened, let container = UIApplication.homeContainerViewController {
                let context = MixinWebViewController.Context(
                    conversationId: "",
                    initialUrl: url,
                    saveAsRecentSearch: true
                )
                container.presentWebViewController(context: context)
            }
            completion(nil)
        }
    }
    
    func cancelPreviousPerformRequest() {
        searchNumberRequest?.cancel()
        searchNumberRequest = nil
    }
    
}
