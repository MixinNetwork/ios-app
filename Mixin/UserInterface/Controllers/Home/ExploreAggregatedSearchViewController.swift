import UIKit
import GRDB
import MixinServices

final class ExploreAggregatedSearchViewController: UIViewController, ExploreSearchViewController {
    
    private enum Section: Int, CaseIterable {
        case quickAccess
        case asset
        case bot
        case dapp
    }
    
    private enum ReuseId {
        static let header = "h"
        static let footer = "f"
    }
    
    weak var tableView: UITableView!
    
    var wantsNavigationSearchBox: Bool {
        true
    }
    
    var navigationSearchBoxInsets: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 20, bottom: 0, right: cancelButton.frame.width + cancelButtonRightMargin)
    }
    
    private let cancelButton = SearchCancelButton()
    private let queue = OperationQueue()
    private let recommendationViewController = ExploreSearchRecommendationViewController()
    private let maxResultsCount = 3
    
    private var lastSearchFieldText: String?
    private var quickAccess: QuickAccessSearchResult?
    private var assetSearchResults: [AssetSearchResult] = []
    private var botSearchResults: [UserSearchResult] = []
    private var dappSearchResults: [Web3Dapp] = []
    private var lastKeyword: String?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = ""
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
        if let exploreViewController {
            cancelButton.addTarget(
                exploreViewController,
                action: #selector(ExploreViewController.cancelSearching(_:)),
                for: .touchUpInside
            )
        }
        
        let tableView = UITableView(frame: view.bounds, style: .grouped)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.backgroundColor = R.color.background()!
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        tableView.register(SearchHeaderView.self, forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(SearchFooterView.self, forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.register(R.nib.quickAccessResultCell)
        tableView.register(R.nib.assetCell)
        tableView.register(R.nib.peerCell)
        tableView.register(R.nib.web3DappCell)
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        
        addChild(recommendationViewController)
        view.addSubview(recommendationViewController.view)
        recommendationViewController.view.snp.makeEdgesEqualToSuperview()
        recommendationViewController.didMove(toParent: self)
        
        queue.maxConcurrentOperationCount = 1
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchTextField.addTarget(self, action: #selector(searchKeyword(_:)), for: .editingChanged)
        navigationSearchBoxView.isBusy = !queue.operations.isEmpty
        if let text = lastSearchFieldText {
            searchTextField.text = text
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTextField.removeTarget(self, action: #selector(searchKeyword(_:)), for: .editingChanged)
        lastSearchFieldText = searchTextField.text
    }
    
    @objc private func searchKeyword(_ sender: Any) {
        guard let keyword = trimmedKeyword?.lowercased() else {
            queue.cancelAllOperations()
            quickAccess = nil
            lastKeyword = nil
            navigationSearchBoxView.isBusy = false
            tableView.reloadData()
            recommendationViewController.view.isHidden = false
            return
        }
        guard keyword != lastKeyword else {
            navigationSearchBoxView.isBusy = false
            return
        }
        quickAccess?.cancelPreviousPerformRequest()
        queue.cancelAllOperations()
        navigationSearchBoxView.isBusy = true
        let limit = maxResultsCount + 1
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            Thread.sleep(forTimeInterval: 0.5)
            guard !op.isCancelled else {
                return
            }
            let quickAccess = QuickAccessSearchResult(keyword: keyword)
            let assetSearchResults = TokenDAO.shared.search(
                keyword: keyword,
                includesZeroBalanceItems: false,
                sorting: true,
                limit: limit
            ).map { token in
                AssetSearchResult(asset: token, keyword: keyword)
            }
            let botSearchResults = UserDAO.shared.getAppUsers(keyword: keyword, limit: limit)
                .map { user in UserSearchResult(user: user, keyword: keyword) }
            let dappSearchResults: [Web3Dapp]
            if keyword.count < 3 {
                dappSearchResults = []
            } else {
                let dapps = DispatchQueue.main.sync {
                    Web3Chain.all.flatMap(\.dapps)
                }
                let uniqueDapps = Array(Set(dapps))
                dappSearchResults = uniqueDapps.filter { dapp in
                    dapp.matches(keyword: keyword)
                }
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                self.quickAccess = quickAccess
                self.lastKeyword = keyword
                self.assetSearchResults = assetSearchResults
                self.botSearchResults = botSearchResults
                self.dappSearchResults = dappSearchResults
                self.reloadTableViewData(showEmptyIndicatorIfEmpty: false)
                self.navigationSearchBoxView.isBusy = false
                self.recommendationViewController.view.isHidden = true
            }
        }
        queue.addOperation(op)
    }
    
    private func isSectionEmpty(_ section: Section) -> Bool {
        switch section {
        case .quickAccess:
            quickAccess == nil
        case .asset:
            assetSearchResults.isEmpty
        case .bot:
            botSearchResults.isEmpty
        case .dapp:
            dappSearchResults.isEmpty
        }
    }
    
    private func isFirstSection(_ section: Section) -> Bool {
        let showTopResult = quickAccess != nil
        return switch section {
        case .quickAccess:
            showTopResult
        case .asset:
            !showTopResult
        case .bot:
            !showTopResult && assetSearchResults.isEmpty
        case .dapp:
            !showTopResult && assetSearchResults.isEmpty && botSearchResults.isEmpty
        }
    }
    
    private func showsFooter(section: Section) -> Bool {
        switch section {
        case .quickAccess:
            false
        case .asset:
            !assetSearchResults.isEmpty && !botSearchResults.isEmpty && !dappSearchResults.isEmpty
        case .bot:
            !botSearchResults.isEmpty && !dappSearchResults.isEmpty
        case .dapp:
            false
        }
    }
    
    private func reloadTableViewData(showEmptyIndicatorIfEmpty: Bool) {
        tableView.reloadData()
        if showEmptyIndicatorIfEmpty {
            let dataCount = (quickAccess == nil ? 0 : 1)
            + botSearchResults.count
            + dappSearchResults.count
            tableView.checkEmpty(
                dataCount: dataCount,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
        } else {
            tableView.removeEmptyIndicator()
        }
    }
    
}

extension ExploreAggregatedSearchViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .quickAccess:
            quickAccess == nil ? 0 : 1
        case .asset:
            min(maxResultsCount, assetSearchResults.count)
        case .bot:
            min(maxResultsCount, botSearchResults.count)
        case .dapp:
            dappSearchResults.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .quickAccess:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.quick_access, for: indexPath)!
            cell.result = quickAccess
            cell.topShadowView.backgroundColor = R.color.background_secondary()
            return cell
        case .asset:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
            let result = assetSearchResults[indexPath.row]
            cell.render(token: result.asset, attributedSymbol: result.attributedSymbol)
            return cell
        case .bot:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            let result = botSearchResults[indexPath.row]
            cell.render(result: result)
            cell.peerInfoView.avatarImageView.hasShadow = false
            return cell
        case .dapp:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_dapp, for: indexPath)!
            let result = dappSearchResults[indexPath.row]
            cell.load(dapp: result)
            return cell
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
}

extension ExploreAggregatedSearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .quickAccess:
            UITableView.automaticDimension
        default:
            70
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = Section(rawValue: section)!
        return switch section {
        case .quickAccess:
            .leastNormalMagnitude
        case .asset, .bot, .dapp:
            if isSectionEmpty(section) {
                .leastNormalMagnitude
            } else {
                SearchHeaderView.height(isFirstSection: isFirstSection(section))
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let section = Section(rawValue: section)!
        return if showsFooter(section: section) {
            SearchFooterView.height
        } else {
            .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = Section(rawValue: section)!
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! SearchHeaderView
        view.isFirstSection = isFirstSection(section)
        view.section = section.rawValue
        view.delegate = self
        
        if isSectionEmpty(section) {
            return nil
        } else {
            switch section {
            case .quickAccess:
                return nil
            case .asset:
                view.label.text = R.string.localizable.assets()
                view.button.isHidden = assetSearchResults.count <= maxResultsCount
                return view
            case .bot:
                view.label.text = R.string.localizable.bots_title()
                view.button.isHidden = botSearchResults.count <= maxResultsCount
                return view
            case .dapp:
                view.label.text = "Apps"
                view.button.isHidden = true
                return view
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let section = Section(rawValue: section)!
        if showsFooter(section: section) {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer) as! SearchFooterView
            view.shadowView.backgroundColor = R.color.background_secondary()
            view.tag = section.rawValue
            return view
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchTextField.resignFirstResponder()
        switch Section(rawValue: indexPath.section)! {
        case .quickAccess:
            quickAccess?.performQuickAccess { [weak self] (item) in
                if let item {
                    let profile = UserProfileViewController(user: item)
                    self?.present(profile, animated: true)
                }
            }
        case .asset:
            let item = assetSearchResults[indexPath.row]
            pushTokenViewController(token: item.asset)
        case .bot:
            let item = botSearchResults[indexPath.row]
            pushConversationViewController(userItem: item.user)
        case .dapp:
            let app = dappSearchResults[indexPath.row]
            presentDapp(app: app)
        }
    }
    
}

extension ExploreAggregatedSearchViewController: SearchHeaderViewDelegate {
    
    func searchHeaderViewDidSendMoreAction(_ view: SearchHeaderView) {
        guard let sectionValue = view.section, let section = Section(rawValue: sectionValue) else {
            return
        }
        searchTextField.resignFirstResponder()
        let viewController: ExploreSearchCategoryViewController
        switch section {
        case .quickAccess, .dapp:
            return
        case .asset:
            viewController = .init(category: .asset)
        case .bot:
            viewController = .init(category: .bot)
        }
        searchNavigationController?.pushViewController(viewController, animated: true)
    }
    
}
