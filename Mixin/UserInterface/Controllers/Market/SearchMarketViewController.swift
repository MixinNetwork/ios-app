import UIKit
import MixinServices

final class SearchMarketViewController: UIViewController, SearchNavigationAnimating {
    
    private let recommendationViewController = SearchMarketRecommendationViewController()
    private let resultsViewController = SearchMarketResultsViewController()
    
    private weak var searchBoxView: SearchBoxView!
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = R.color.background()
        
        let searchBoxView = SearchBoxView()
        searchBoxView.textField.rightViewMode = .always
        searchBoxView.textField.addTarget(
            self,
            action: #selector(textFieldDidChange(_:)),
            for: .editingChanged
        )
        navigationItem.hidesBackButton = true
        navigationItem.titleView = searchBoxView
        self.searchBoxView = searchBoxView
        navigationItem.rightBarButtonItem = .cancelSearch(
            target: self,
            action: #selector(cancelSearching)
        )
        
        addChild(resultsViewController)
        view.addSubview(resultsViewController.view)
        resultsViewController.view.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        resultsViewController.didMove(toParent: self)
        resultsViewController.view.isHidden = true
        
        addChild(recommendationViewController)
        view.addSubview(recommendationViewController.view)
        recommendationViewController.view.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        recommendationViewController.didMove(toParent: self)
        recommendationViewController.view.isHidden = false
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dismissSearch),
            name: dismissSearchNotification,
            object: nil,
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isMovingToParent {
            searchBoxView.textField.becomeFirstResponder()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchBoxView.textField.resignFirstResponder()
    }
    
    @objc private func cancelSearching() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func dismissSearch() {
        guard let navigationController else {
            return
        }
        let viewControllers = navigationController.viewControllers.filter { $0 !== self }
        navigationController.setViewControllers(viewControllers, animated: false)
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        let keyword = (textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty {
            searchBoxView.isBusy = false
            recommendationViewController.view.isHidden = false
            resultsViewController.view.isHidden = true
            resultsViewController.clear()
        } else {
            searchBoxView.isBusy = true
            recommendationViewController.view.isHidden = true
            resultsViewController.view.isHidden = false
            resultsViewController.search(keyword: keyword) { [weak searchBoxView] in
                searchBoxView?.isBusy = false
            }
        }
    }
    
    func viewCrypto(_ market: FavorableMarket) {
        searchBoxView.textField.resignFirstResponder()
        AppGroupUserDefaults.User.insertRecentMarketSearch(
            .crypto(coinID: market.coinID)
        )
        let controller = MarketViewController(market: market)
        navigationController?.pushViewController(controller, animated: true)
        reporter.report(
            event: .marketDetail,
            tags: [
                "type": "spot",
                "source": "markets_search",
            ],
        )
    }
    
    func viewPerpetual(_ market: PerpetualMarket) {
        searchBoxView.textField.resignFirstResponder()
        AppGroupUserDefaults.User.insertRecentMarketSearch(
            .perps(marketID: market.marketID)
        )
        let viewModel = PerpetualMarketViewModel(market: market)
        let controller = PerpetualMarketViewController(
            wallet: .privacy,
            viewModel: viewModel,
        )
        navigationController?.pushViewController(controller, animated: true)
        reporter.report(
            event: .marketDetail,
            tags: [
                "type": "perps",
                "source": "markets_search",
            ],
        )
    }
    
}
