import UIKit
import MixinServices

final class SearchMarketViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var contentWrapperView: UIView!
    
    private let recommendationViewController = SearchMarketRecommendationViewController()
    private let resultsViewController = SearchMarketResultsViewController()
    
    init() {
        let nib = R.nib.searchMarketView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.rightViewMode = .always
        searchBoxView.textField.addTarget(
            self,
            action: #selector(textFieldDidChange(_:)),
            for: .editingChanged
        )
        updateCancelButtonTarget(parent: parent)
        
        addChild(resultsViewController)
        contentWrapperView.addSubview(resultsViewController.view)
        resultsViewController.view.snp.makeEdgesEqualToSuperview()
        resultsViewController.didMove(toParent: self)
        resultsViewController.view.isHidden = true
        
        addChild(recommendationViewController)
        contentWrapperView.addSubview(recommendationViewController.view)
        recommendationViewController.view.snp.makeEdgesEqualToSuperview()
        recommendationViewController.didMove(toParent: self)
        recommendationViewController.view.isHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchBoxView.textField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchBoxView.textField.resignFirstResponder()
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        updateCancelButtonTarget(parent: parent)
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
    
    private func updateCancelButtonTarget(parent: UIViewController?) {
        guard let cancelButton else {
            return
        }
        cancelButton.removeTarget(nil, action: nil, for: .touchUpInside)
        if let parent = parent as? MarketDashboardViewController {
            cancelButton.addTarget(
                parent,
                action: #selector(MarketDashboardViewController.cancelSearching(_:)),
                for: .touchUpInside
            )
        }
    }
    
}
