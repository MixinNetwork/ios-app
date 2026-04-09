import UIKit
import Combine
import MixinServices

final class PerpetualMarketSelectorViewController: TokenSelectorViewController {
    
    var onSelected: ((PerpetualMarketViewModel) -> Void)?
    
    private var searchObserver: AnyCancellable?
    private var searchResultsKeyword: String?
    private var searchResults: [PerpetualMarketViewModel]?
    private var markets: [PerpetualMarketViewModel] = []
    
    deinit {
        searchObserver?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self, action: #selector(prepareForSearch(_:)), for: .editingChanged)
        searchBoxView.textField.delegate = self
        searchObserver = NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: searchBoxView.textField)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                let keyword = self.trimmedKeyword
                guard !keyword.isEmpty, keyword != self.searchResultsKeyword else {
                    self.searchBoxView.isBusy = false
                    return
                }
                self.search(keyword: keyword)
            }
        collectionView.register(R.nib.perpetualMarketCell)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { (_, _) in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 20
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
            return section
        }
        collectionView.allowsMultipleSelection = false
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil
        )
        reloadData()
    }
    
    @objc private func prepareForSearch(_ textField: UITextField) {
        let keyword = self.trimmedKeyword
        if keyword.isEmpty {
            searchResultsKeyword = nil
            searchResults = nil
            collectionView.reloadData()
            collectionView.checkEmpty(
                dataCount: markets.count,
                text: R.string.localizable.dont_have_assets(),
                photo: R.image.emptyIndicator.ic_hidden_assets()!
            )
            searchBoxView.isBusy = false
        } else if keyword != searchResultsKeyword {
            searchBoxView.isBusy = true
        }
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let markets = PerpsMarketDAO.shared.availableMarkets(limit: nil)
            let viewModels = markets.compactMap(PerpetualMarketViewModel.init(market:))
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.markets = viewModels
                UIView.performWithoutAnimation(self.collectionView.reloadData)
            }
        }
    }
    
    func search(keyword: String) {
        let lowercasedKeyword = keyword.lowercased()
        let searchResults = markets.filter { viewModel in
            viewModel.market.tokenSymbol.lowercased().contains(lowercasedKeyword)
        }
        self.searchResultsKeyword = keyword
        self.searchResults = searchResults
        collectionView.reloadData()
        collectionView.checkEmpty(
            dataCount: searchResults.count,
            text: R.string.localizable.no_results(),
            photo: R.image.emptyIndicator.ic_search_result()!
        )
        searchBoxView.isBusy = false
    }
    
    private func viewModel(at indexPath: IndexPath) -> PerpetualMarketViewModel {
        if let searchResults {
            searchResults[indexPath.item]
        } else {
            markets[indexPath.item]
        }
    }
    
}

extension PerpetualMarketSelectorViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension PerpetualMarketSelectorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        searchResults?.count ?? markets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
        let viewModel = viewModel(at: indexPath)
        cell.load(viewModel: viewModel)
        return cell
    }
    
}

extension PerpetualMarketSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let token = viewModel(at: indexPath)
        onSelected?(token)
    }
    
}
