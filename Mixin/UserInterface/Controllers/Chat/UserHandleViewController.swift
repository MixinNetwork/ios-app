import UIKit
import MixinServices

class UserHandleViewController: UITableViewController {
    
    private struct SearchResult {
        let user: UserItem
        let fullnameKeywordRange: NSRange?
        let identityNumberKeywordRange: NSRange?
    }
    
    var users = [UserItem]() {
        didSet {
            guard let keyword = keyword else {
                return
            }
            reload(with: keyword, completion: nil)
        }
    }
    
    var tableHeaderHeight: CGFloat {
        tableHeaderView.frame.height
    }
    
    private let initialVisibleCellsCount: CGFloat = {
        if ScreenHeight.current <= .short {
            return 2.5
        } else {
            return 3.5
        }
    }()
    
    private var searchResults = [SearchResult]()
    private var keyword: String?
    private var onScrollingAnimationEnd: (() -> ())?
    
    private weak var conversationViewController: ConversationViewController?
    
    private lazy var tableHeaderView: UserHandleTableHeaderView = {
        let frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 100)
        let view = UserHandleTableHeaderView(frame: frame)
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var tableFooterView: UIView = {
        let frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 7)
        let view = UIView(frame: frame)
        view.backgroundColor = .background
        let bottomFillingBackgroundView = UIView()
        bottomFillingBackgroundView.backgroundColor = .background
        view.addSubview(bottomFillingBackgroundView)
        bottomFillingBackgroundView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.snp.bottom)
            make.height.equalTo(900)
        }
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear
        tableView.tableHeaderView = tableHeaderView
        tableView.tableFooterView = tableFooterView
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let contentHeight = min(CGFloat(searchResults.count), initialVisibleCellsCount) * tableView.rowHeight
            + UserHandleTableHeaderView.decorationHeight
        let tableHeaderHeight = max(0, tableView.frame.height - contentHeight)
        if tableHeaderView.frame.height != tableHeaderHeight {
            tableHeaderView.frame.size.height = tableHeaderHeight
            tableView.tableHeaderView = tableHeaderView
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        conversationViewController = parent as? ConversationViewController
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.user_handle, for: indexPath)!
        let result = searchResults[indexPath.row]
        cell.render(user: result.user,
                    fullnameKeywordRange: result.fullnameKeywordRange,
                    identityNumberKeywordRange: result.identityNumberKeywordRange)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let result = searchResults[indexPath.row]
        conversationViewController?.inputUserHandle(with: result.user)
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        conversationViewController?.updateUserHandleMask()
    }
    
    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        onScrollingAnimationEnd?()
        onScrollingAnimationEnd = nil
    }
    
    func reload(with keyword: String?, completion: ((Bool) -> ())?) {
        self.keyword = keyword
        let hadContent = !searchResults.isEmpty
        let searchResults: [SearchResult]
        if let keyword = keyword {
            searchResults = users.compactMap({ (user) -> SearchResult? in
                guard !keyword.isEmpty else {
                    return SearchResult(user: user,
                                        fullnameKeywordRange: nil,
                                        identityNumberKeywordRange: nil)
                }
                let fullnameKeywordRange = (user.fullName as NSString).range(of: keyword, options: [.caseInsensitive])
                let identityNumberKeywordRange = (user.identityNumber as NSString).range(of: keyword)
                if fullnameKeywordRange.location != NSNotFound {
                    return SearchResult(user: user,
                                        fullnameKeywordRange: fullnameKeywordRange,
                                        identityNumberKeywordRange: nil)
                } else if identityNumberKeywordRange.location != NSNotFound {
                    return SearchResult(user: user,
                                        fullnameKeywordRange: nil,
                                        identityNumberKeywordRange: identityNumberKeywordRange)
                } else {
                    return nil
                }
            })
        } else {
            searchResults = []
        }
        let hasContent = !searchResults.isEmpty
        if !hadContent && hasContent {
            loadViewIfNeeded()
            self.searchResults = searchResults
            tableView.reloadData()
            completion?(true)
            onScrollingAnimationEnd = nil
            view.setNeedsLayout()
            view.layoutIfNeeded()
            let diff = view.frame.height - tableHeaderView.frame.height
            tableView.contentOffset.y = -diff
            self.tableView.setContentOffset(.zero, animated: true)
        } else if searchResults.isEmpty {
            let diff = view.frame.height - tableHeaderView.frame.height
            let offset = CGPoint(x: 0, y: -diff)
            onScrollingAnimationEnd = { [weak self] in
                if let weakSelf = self {
                    weakSelf.searchResults = searchResults
                    weakSelf.tableView.reloadData()
                }
                completion?(hasContent)
            }
            self.tableView.setContentOffset(offset, animated: true)
        } else {
            self.searchResults = searchResults
            onScrollingAnimationEnd = nil
            tableView.reloadData()
            tableView.setContentOffset(.zero, animated: false)
            view.layoutIfNeeded()
            completion?(hasContent)
        }
    }
    
}
