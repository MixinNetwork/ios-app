import UIKit
import MixinServices

final class ExploreSearchRecommendationViewController: UIViewController {
    
    private let layout = LeftAlignedCollectionViewFlowLayout()
    
    private var viewModels: [RecentSearchViewModel] = []
    
    private weak var collectionView: UICollectionView!
    
    override func loadView() {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.collectionView = collectionView
        self.view = collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        layout.minimumInteritemSpacing = 16
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.backgroundColor = R.color.background()
        collectionView.register(R.nib.exploreRecentSearchCell)
        collectionView.register(R.nib.recentSearchHeaderView, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.dataSource = self
        collectionView.delegate = self
        reloadData()
    }
    
    private func reloadData() {
        DispatchQueue.global().async {
            let searches = AppGroupUserDefaults.User.recentSearches
            let viewModels: [RecentSearchViewModel] = searches.compactMap { item in
                switch item {
                case let .market(coinID):
                    if let market = MarketDAO.shared.market(coinID: coinID) {
                        .market(market)
                    } else {
                        nil
                    }
                case let .app(userID):
                    if let item = UserDAO.shared.getUser(userId: userID) {
                        .user(item)
                    } else {
                        nil
                    }
                }
            }
            DispatchQueue.main.async {
                self.viewModels = viewModels
                self.collectionView.reloadData()
            }
        }
    }
    
}

extension ExploreSearchRecommendationViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_recent_search, for: indexPath)!
        let viewModel = viewModels[indexPath.item]
        switch viewModel.content {
        case let .market(market):
            cell.tokenIconView.setIcon(market: market)
            cell.tokenIconView.isHidden = false
            cell.avatarImageView.isHidden = true
        case let .user(item):
            cell.avatarImageView.setImage(with: item)
            cell.tokenIconView.isHidden = true
            cell.avatarImageView.isHidden = false
        case .link:
            break
        }
        cell.titleLabel.text = viewModel.title
        cell.subtitleLabel.text = viewModel.subtitle
        if let color = viewModel.subtitleColor {
            cell.subtitleLabel.marketColor = color
        } else {
            cell.subtitleLabel.textColor = R.color.text_tertiary()
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: R.reuseIdentifier.recent_search_header,
            for: indexPath
        )!
        view.delegate = self
        return view
    }
    
}

extension ExploreSearchRecommendationViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let parent = parent as? ExploreAggregatedSearchViewController else {
            return
        }
        let viewModel = viewModels[indexPath.item]
        switch viewModel.content {
        case let .market(market):
            parent.pushMarketViewController(market: market)
        case let .user(item):
            parent.pushConversationViewController(userItem: item)
        case .link:
            break
        }
    }
    
}

extension ExploreSearchRecommendationViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if viewModels.isEmpty {
            .zero
        } else {
            CGSize(width: collectionView.bounds.width, height: 56)
        }
    }
    
}

extension ExploreSearchRecommendationViewController: RecentSearchHeaderView.Delegate {
    
    func recentSearchHeaderViewDidSendAction(_ view: RecentSearchHeaderView) {
        viewModels = []
        collectionView.reloadData()
        AppGroupUserDefaults.User.removeAllRecentSearches()
    }
    
}

extension ExploreSearchRecommendationViewController {
    
    private enum Section: Int {
        case recentSearches
    }
    
    private struct RecentSearchViewModel {
        
        enum Content {
            case market(FavorableMarket)
            case user(UserItem)
            case link(URL)
        }
        
        let content: Content
        let title: String
        let subtitle: String
        let subtitleColor: MarketColor?
        
        static func market(_ market: FavorableMarket) -> RecentSearchViewModel {
            RecentSearchViewModel(
                content: .market(market),
                title: market.symbol,
                subtitle: market.localizedPriceChangePercentage7D ?? "",
                subtitleColor: .byValue(market.decimalPriceChangePercentage7D)
            )
        }
        
        static func user(_ item: UserItem) -> RecentSearchViewModel {
            RecentSearchViewModel(
                content: .user(item),
                title: item.fullName,
                subtitle: item.identityNumber,
                subtitleColor: nil
            )
        }
        
        static func link(url: URL, title: String) -> RecentSearchViewModel {
            RecentSearchViewModel(
                content: .link(url),
                title: title,
                subtitle: url.host ?? url.absoluteString,
                subtitleColor: nil
            )
        }
        
    }
    
}
