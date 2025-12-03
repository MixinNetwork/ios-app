import UIKit
import Combine
import MixinServices

final class BuyTokenSelectorViewController: TokenSelectorViewController {
    
    typealias Token = ValuableToken & OnChainToken
    
    var onSelected: ((Token) -> Void)?
    
    private let tokens: [any Token]
    private let selectedAssetID: String?
    
    private var searchObserver: AnyCancellable?
    private var searchResultsKeyword: String?
    private var searchResults: [any Token]?
    
    init(tokens: [any Token], selectedAssetID: String?) {
        self.tokens = tokens
        self.selectedAssetID = selectedAssetID
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
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
        collectionView.register(R.nib.tradeTokenCell)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { (_, _) in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50))
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 20
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0)
            return section
        }
        collectionView.allowsMultipleSelection = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
    }
    
    @objc func prepareForSearch(_ textField: UITextField) {
        let keyword = self.trimmedKeyword
        if keyword.isEmpty {
            searchResultsKeyword = nil
            searchResults = nil
            collectionView.reloadData()
            collectionView.checkEmpty(
                dataCount: tokens.count,
                text: R.string.localizable.dont_have_assets(),
                photo: R.image.emptyIndicator.ic_hidden_assets()!
            )
            searchBoxView.isBusy = false
        } else if keyword != searchResultsKeyword {
            searchBoxView.isBusy = true
        }
    }
    
    func search(keyword: String) {
        
    }
    
    private func token(at indexPath: IndexPath) -> any Token {
        if let searchResults {
            searchResults[indexPath.item]
        } else {
            tokens[indexPath.item]
        }
    }
    
}

extension BuyTokenSelectorViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension BuyTokenSelectorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        searchResults?.count ?? tokens.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_token, for: indexPath)!
        let token = token(at: indexPath)
        cell.iconView.setIcon(token: token, chain: token.chain)
        cell.maliciousWarningImageView.isHidden = true
        cell.titleLabel.text = token.name
        cell.subtitleLabel.text = token.localizedBalanceWithSymbol
        if let tag = token.chainTag {
            cell.chainLabel.text = tag
            cell.chainLabel.isHidden = false
        } else {
            cell.chainLabel.isHidden = true
        }
        return cell
    }
    
}

extension BuyTokenSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let token = token(at: indexPath)
        onSelected?(token)
    }
    
}
