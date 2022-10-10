import UIKit
import MixinServices

protocol TransferTypeViewControllerDelegate: AnyObject {
    
    func transferTypeViewController(_ viewController: TransferTypeViewController, didSelectAsset asset: AssetItem)
    func transferTypeViewControllerDidSelectDeposit(_ viewController: TransferTypeViewController)
    
}

class TransferTypeViewController: PopupSearchableTableViewController {
    
    weak var delegate: TransferTypeViewControllerDelegate?
    
    var assets = [AssetItem]()
    var asset: AssetItem?
    var showEmptyHintIfNeeded: Bool = false
    
    private var searchResults = [AssetItem]()
    private var emptyHintViewIfLoaded: UIView?

    convenience init() {
        self.init(nib: R.nib.popupSearchableTableView)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        if let assetId = asset?.assetId, let index = assets.firstIndex(where: { $0.assetId == assetId }) {
            var reordered = assets
            let selected = reordered.remove(at: index)
            reordered.insert(selected, at: 0)
            self.assets = reordered
        }
        tableView.register(R.nib.transferTypeCell)
        tableView.dataSource = self
        tableView.delegate = self
        if showEmptyHintIfNeeded && assets.isEmpty {
            loadEmptyHintView()
            searchBoxView.isUserInteractionEnabled = false
        } else {
            tableView.reloadData()
        }
    }
    
    override func updateSearchResults(keyword: String) {
        searchResults = assets.filter({ (asset) -> Bool in
            asset.symbol.lowercased().contains(keyword)
                || asset.name.lowercased().contains(keyword)
        })
    }
    
    func reloadAssets(_ assets: [AssetItem]) {
        emptyHintViewIfLoaded?.removeFromSuperview()
        searchBoxView.isUserInteractionEnabled = true
        self.assets = assets
        tableView.reloadData()
    }
    
}

extension TransferTypeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.transfer_type, for: indexPath)!
        let asset = isSearching ? searchResults[indexPath.row] : assets[indexPath.row]
        cell.checkmarkView.isHidden = !(asset.assetId == self.asset?.assetId)
        cell.render(asset: asset)
        return cell
    }
    
}

extension TransferTypeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let asset = isSearching ? searchResults[indexPath.row] : assets[indexPath.row]
        delegate?.transferTypeViewController(self, didSelectAsset: asset)
        dismiss(animated: true, completion: nil)
    }
    
}

extension TransferTypeViewController {
    
    @objc private func deposit() {
        delegate?.transferTypeViewControllerDidSelectDeposit(self)
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
    
}
