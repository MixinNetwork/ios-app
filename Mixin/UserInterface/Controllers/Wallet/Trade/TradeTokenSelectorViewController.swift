import UIKit
import OrderedCollections
import Alamofire
import MixinServices

class TradeTokenSelectorViewController: ChainCategorizedTokenSelectorViewController<BalancedSwapToken> {
    
    let intent: TokenSelectorIntent
    let recentAssetIDsKey: PropertiesDAO.Key
    
    weak var searchRequest: Request?
    
    var onSelected: ((BalancedSwapToken) -> Void)?
    
    private let stockTokens: [BalancedSwapToken]
    
    private var isViewingStockTokens = false
    
    private var stockCategoryCellIndexPath: IndexPath {
        IndexPath(
            item: (searchResultChains ?? defaultChains).count + 1,
            section: Section.chainSelector.rawValue
        )
    }
    
    init(
        intent: TokenSelectorIntent,
        selectedAssetID: String?,
        defaultTokens: [BalancedSwapToken],
        stockTokens: [BalancedSwapToken],
    ) {
        self.intent = intent
        self.recentAssetIDsKey = switch intent {
        case .send:
                .mixinSwapRecentSendIDs
        case .receive:
                .mixinSwapRecentReceiveIDs
        }
        self.stockTokens = stockTokens
        super.init(
            defaultTokens: defaultTokens,
            defaultChains: [],
            searchDebounceInterval: 0.5,
            selectedID: selectedAssetID
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        searchRequest?.cancel()
        operationQueue.cancelAllOperations()
    }
    
    override func prepareForSearch(_ textField: UITextField) {
        searchRequest?.cancel()
        operationQueue.cancelAllOperations()
        super.prepareForSearch(textField)
    }
    
    override func saveRecentsToStorage(tokens: any Sequence<BalancedSwapToken>) {
        PropertiesDAO.shared.set(
            jsonObject: tokens.map(\.assetID),
            forKey: recentAssetIDsKey
        )
    }
    
    override func clearRecentsStorage() {
        PropertiesDAO.shared.removeValue(forKey: recentAssetIDsKey)
    }
    
    override func tokenIndices(tokens: [BalancedSwapToken], chainID: String) -> [Int] {
        tokens.enumerated().compactMap { (index, token) in
            if token.chain.chainID == chainID {
                index
            } else {
                nil
            }
        }
    }
    
    override func configureRecentCell(_ cell: ExploreRecentSearchCell, withToken token: BalancedSwapToken) {
        cell.setBadgeIcon { iconView in
            iconView.setIcon(swappableToken: token)
        }
        cell.titleLabel.text = token.symbol
        if let change = recentTokenChanges[token.assetID] {
            cell.subtitleLabel.marketColor = change.value >= 0 ? .rising : .falling
            cell.subtitleLabel.text = change.description
        } else {
            cell.subtitleLabel.textColor = R.color.text_tertiary()
            cell.subtitleLabel.text = token.name
        }
    }
    
    override func configureTokenCell(_ cell: TradeTokenCell, withToken token: BalancedSwapToken) {
        cell.iconView.setIcon(swappableToken: token)
        cell.maliciousWarningImageView.isHidden = true
        cell.titleLabel.text = token.name
        cell.subtitleLabel.text = token.localizedBalanceWithSymbol
        if let tag = token.chainTag {
            cell.chainLabel.text = tag
            cell.chainLabel.isHidden = false
        } else {
            cell.chainLabel.isHidden = true
        }
    }
    
    override func pickUp(token: BalancedSwapToken, from location: PickUpLocation) {
        super.pickUp(token: token, from: location)
        presentingViewController?.dismiss(animated: true)
        onSelected?(token)
        reporter.report(event: .tradeTokenSelect, tags: ["method": location.asEventMethod])
    }
    
    override func reloadChainSelection() {
        if isViewingStockTokens {
            collectionView.selectItem(at: stockCategoryCellIndexPath, animated: false, scrollPosition: [])
        } else {
            super.reloadChainSelection()
        }
    }
    
    override func reloadTokenSelection() {
        if let id = selectedID,
           isViewingStockTokens,
           let item = stockTokens.firstIndex(where: { $0.assetID == id })
        {
            let indexPath = IndexPath(item: item, section: Section.tokens.rawValue)
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        } else {
            super.reloadTokenSelection()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let number = super.collectionView(collectionView, numberOfItemsInSection: section)
        let section = Section(rawValue: section)!
        if searchResultChains != nil || stockTokens.isEmpty {
            return number
        } else {
            switch section {
            case .chainSelector:
                return number + 1 // 1 for stocks
            case .tokens where isViewingStockTokens:
                return stockTokens.count
            default:
                return number
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath == stockCategoryCellIndexPath {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            cell.label.text = R.string.localizable.stocks()
            return cell
        } else if indexPath.section == Section.tokens.rawValue && isViewingStockTokens {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_token, for: indexPath)!
            let token = stockTokens[indexPath.item]
            configureTokenCell(cell, withToken: token)
            return cell
        } else {
            return super.collectionView(collectionView, cellForItemAt: indexPath)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let stockCellIndexPath = self.stockCategoryCellIndexPath
        if indexPath.section == stockCellIndexPath.section && indexPath.item != stockCellIndexPath.item {
            isViewingStockTokens = false
        }
        return super.collectionView(collectionView, shouldSelectItemAt: indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath == stockCategoryCellIndexPath {
            isViewingStockTokens = true
            reloadWithoutAnimation(section: .tokens)
            reloadTokenSelection()
        } else if indexPath.section == Section.tokens.rawValue && isViewingStockTokens {
            let token = stockTokens[indexPath.item]
            pickUp(token: token, from: .stock)
        } else {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }
    
}
