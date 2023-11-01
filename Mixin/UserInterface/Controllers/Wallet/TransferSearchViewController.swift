import UIKit
import MixinServices

protocol TransferSearchViewControllerDelegate: AnyObject {
    
    func transferSearchViewController(_ viewController: TransferSearchViewController, didSelectToken token: TokenItem)
    func transferSearchViewControllerDidSelectDeposit(_ viewController: TransferSearchViewController)
    
}

class TransferSearchViewController: PopupSearchableTableViewController {
    
    weak var delegate: TransferSearchViewControllerDelegate?
    
    var tokens = [TokenItem]()
    var sendableAssets = [TokenItem]()
    var showEmptyHintIfNeeded = false
    var searchResultsFromServer = false
    
    private var emptyHintViewIfLoaded: UIView?
    private let searchResultsController = WalletTransferSearchResultsViewController()

    convenience init() {
        self.init(nib: R.nib.popupSearchableTableView)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        addChild(searchResultsController)
        view.addSubview(searchResultsController.view)
        searchResultsController.view.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(searchBoxView.snp.bottom).offset(10)
        }
        searchResultsController.didMove(toParent: self)
        searchResultsController.transferSearchController = self
        reloadSearchResults(tokens)
        if tokens.isEmpty, showEmptyHintIfNeeded {
            loadEmptyHintView()
            searchBoxView.isUserInteractionEnabled = false
        }
    }
    
    override func searchAction(_ sender: Any) {
        guard keyword != searchResultsController.lastKeyword else {
            return
        }
        if searchResultsFromServer {
            if keyword.isEmpty {
                searchResultsController.lastKeyword = keyword
                reloadSearchResults(tokens)
            } else {
                searchResultsController.update(with: keyword)
            }
        } else {
            searchResultsController.lastKeyword = keyword
            let results: [TokenItem]
            if keyword.isEmpty {
                results = tokens
            } else {
                results = sendableAssets.filter({ (asset) -> Bool in
                    asset.symbol.lowercased().contains(keyword) || asset.name.lowercased().contains(keyword)
                })
            }
            reloadSearchResults(results)
        }
    }
    
    func reload(tokens: [TokenItem]) {
        emptyHintViewIfLoaded?.removeFromSuperview()
        searchBoxView.isUserInteractionEnabled = true
        self.tokens = tokens
        reloadSearchResults(tokens)
    }
    
}

extension TransferSearchViewController {
    
    @objc private func deposit() {
        delegate?.transferSearchViewControllerDidSelectDeposit(self)
    }
    
    private func loadEmptyHintView() {
        let emptyHintView = UIView()
        let label = UILabel()
        label.textColor = R.color.text_accessory()
        label.font = .systemFont(ofSize: 14)
        label.text = R.string.localizable.dont_have_assets()
        emptyHintView.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
        }
        let button = UIButton()
        button.setTitle(R.string.localizable.deposit(), for: .normal)
        button.setTitleColor(R.color.theme(), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.addTarget(self, action: #selector(deposit), for: .touchUpInside)
        emptyHintView.addSubview(button)
        button.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(label.snp.bottom).offset(15)
            make.bottom.equalToSuperview()
        }
        view.addSubview(emptyHintView)
        emptyHintView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        emptyHintViewIfLoaded = emptyHintView
    }

    private func reloadSearchResults(_ tokens: [TokenItem]) {
        searchResultsController.searchResults = tokens
        searchResultsController.tableView.reloadData()
    }
    
}
