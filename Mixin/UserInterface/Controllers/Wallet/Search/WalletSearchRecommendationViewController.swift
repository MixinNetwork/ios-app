import UIKit
import MixinServices

final class WalletSearchRecommendationViewController<ModelController: WalletSearchModelController>: WalletSearchTableViewController, UITableViewDataSource, UITableViewDelegate {
    
    private enum ReuseID {
        static var header: String { "h" }
        static var footer: String { "f" }
    }
    
    private enum Section: Int, CaseIterable {
        case history = 0
        case trending
    }
    
    private let modelController: ModelController
    private let queue = DispatchQueue(label: "one.mixin.messenger.WalletSearchRecommendation")
    
    private var history: [ModelController.Item] = []
    private var trending: [AssetItem] = []
    
    init(modelController: ModelController) {
        self.modelController = modelController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(
            SearchHeaderView.self,
            forHeaderFooterViewReuseIdentifier: ReuseID.header
        )
        tableView.register(
            SearchFooterView.self,
            forHeaderFooterViewReuseIdentifier: ReuseID.footer
        )
        tableView.dataSource = self
        tableView.delegate = self
        
        queue.async { [modelController, weak self] in
            let history = modelController.history()
            let trending = TopAssetsDAO.shared.getAssets()
                .filter(modelController.isTrendingItemAvailable(item:))
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.history = history
                self.trending = trending
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
            }
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadTrending),
                                               name: TopAssetsDAO.didChangeNotification,
                                               object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshTopAssetsJob())
    }
    
    @objc private func reloadTrending() {
        let trendingSection = IndexSet(arrayLiteral: Section.trending.rawValue)
        queue.async { [modelController, weak self] in
            let trending = TopAssetsDAO.shared.getAssets()
                .filter(modelController.isTrendingItemAvailable(item:))
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.trending = trending
                self.tableView.reloadSections(trendingSection, with: .none)
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .history:
            return history.count
        case .trending:
            return trending.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        switch Section(rawValue: indexPath.section)! {
        case .history:
            let item = history[indexPath.row]
            cell.render(token: item, style: .symbolWithName)
        case .trending:
            let item = trending[indexPath.row]
            cell.render(asset: item)
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .history where !history.isEmpty:
            return SearchHeaderView.height(isFirstSection: true)
        case .trending where !trending.isEmpty:
            return SearchHeaderView.height(isFirstSection: history.isEmpty)
        default:
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if Section(rawValue: section) == .history && !history.isEmpty {
            return SearchFooterView.height
        } else {
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseID.header) as! SearchHeaderView
        switch Section(rawValue: section)! {
        case .history where !history.isEmpty:
            view.label.text = R.string.localizable.recent_searches()
        case .trending where !trending.isEmpty:
            view.label.text = R.string.localizable.trending()
        default:
            return nil
        }
        view.button.isHidden = true
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if Section(rawValue: section) == .history && !history.isEmpty {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseID.footer)!
            view.contentView.backgroundColor = .secondaryBackground
            return view
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .history:
            let item = history[indexPath.row]
            modelController.reportUserSelection(token: item)
        case .trending:
            let item = trending[indexPath.row]
            modelController.reportUserSelection(trending: item)
        }
    }
    
}
