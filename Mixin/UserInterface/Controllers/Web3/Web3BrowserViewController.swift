import UIKit
import OrderedCollections
import Alamofire
import MixinServices

final class Web3BrowserViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    private let category: Web3Chain.Category
    
    private var quickAccess: QuickAccessSearchResult?
    private var searchResults: [Web3Dapp] = []
    private var lastKeyword: String?
    
    init(category: Web3Chain.Category) {
        self.category = category
        let nib = R.nib.exploreSearchView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_dapp()
        searchBoxView.textField.addTarget(self, action: #selector(searchKeyword(_:)), for: .editingChanged)
        searchBoxView.textField.becomeFirstResponder()
        
        tableView.register(R.nib.web3DappCell)
        tableView.register(R.nib.quickAccessResultCell)
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    @IBAction func cancelSearching(_ sender: Any) {
        searchBoxView.textField.resignFirstResponder()
        (parent as? ExploreViewController)?.cancelSearching()
    }
    
    @objc private func searchKeyword(_ sender: Any) {
        guard let keyword = searchBoxView.spacesTrimmedText?.lowercased() else {
            lastKeyword = nil
            quickAccess = nil
            searchResults = []
            tableView.reloadData()
            tableView.removeEmptyIndicator()
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        guard keyword.count >= 3 else {
            lastKeyword = nil
            quickAccess = nil
            searchResults = []
            tableView.reloadData()
            tableView.checkEmpty(dataCount: searchResults.count,
                                 text: R.string.localizable.no_results(),
                                 photo: R.image.emptyIndicator.ic_data()!)
            return
        }
        quickAccess = QuickAccessSearchResult(keyword: keyword)
        var dapps: OrderedSet<Web3Dapp> = category.chains.reduce(into: []) { results, chain in
            results.formUnion(chain.dapps)
        }
        searchResults = dapps.filter { dapp in
            dapp.matches(keyword: keyword)
        }
        tableView.reloadData()
        let quickAccessCount = quickAccess == nil ? 0 : 1
        tableView.checkEmpty(dataCount: quickAccessCount + searchResults.count,
                             text: R.string.localizable.no_results(),
                             photo: R.image.emptyIndicator.ic_data()!)
        self.lastKeyword = keyword
    }
    
}

extension Web3BrowserViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        quickAccess == nil ? 1 : 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if quickAccess != nil && section == 0 {
            1
        } else {
            searchResults.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let quickAccess, indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.quick_access, for: indexPath)!
            cell.result = quickAccess
            cell.topShadowView.backgroundColor = R.color.background_secondary()
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_dapp, for: indexPath)!
            let result = searchResults[indexPath.row]
            cell.iconImageView.sd_setImage(with: result.iconURL)
            cell.nameLabel.text = result.name
            cell.hostLabel.text = result.host
            return cell
        }
    }
    
}

extension Web3BrowserViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if quickAccess != nil, indexPath.section == 0 {
            UITableView.automaticDimension
        } else {
            tableView.rowHeight
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let quickAccess, indexPath.section == 0 {
            quickAccess.performQuickAccess() { [weak self] item in
                guard let item else {
                    return
                }
                let profile = UserProfileViewController(user: item)
                self?.present(profile, animated: true)
            }
        } else {
            if let container = UIApplication.homeContainerViewController?.homeTabBarController {
                let url = searchResults[indexPath.row].homeURL
                MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url),
                                                       asChildOf: container)
            }
        }
    }
    
}
