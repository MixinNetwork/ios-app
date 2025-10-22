import UIKit
import MixinServices

final class ExploreSearchRecommendationViewController: UIViewController {
    
    private let groupHorizontalMargin: CGFloat = 20
    
    private var viewModels: [RecentSearchViewModel] = []
    
    private weak var collectionView: UICollectionView!
    
    override func loadView() {
        let layout = UICollectionViewCompositionalLayout { [weak self, groupHorizontalMargin] sectionIndex, environment in
            let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(114), heightDimension: .estimated(47))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(47))
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(16)
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: groupHorizontalMargin, bottom: 0, trailing: groupHorizontalMargin)
            let section = NSCollectionLayoutSection(group: group)
            if let self, !self.viewModels.isEmpty {
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    )
                ]
            }
            section.interGroupSpacing = 12
            return section
        }
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.collectionView = collectionView
        self.view = collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.backgroundColor = R.color.background()
        collectionView.register(R.nib.exploreRecentSearchCell)
        collectionView.register(R.nib.recentSearchHeaderView, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: AppGroupUserDefaults.User.recentSearchesDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: MarketDAO.didUpdateNotification,
            object: nil
        )
        reloadData()
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async {
            let searches = AppGroupUserDefaults.User.recentSearches
            let viewModels: [RecentSearchViewModel] = searches.compactMap { item in
                switch item {
                case let .mixinToken(assetID):
                    if let token = TokenDAO.shared.tokenItem(assetID: assetID) {
                       return .mixinToken(token)
                    } else {
                        return nil
                    }
                case let .app(userID):
                    if let item = UserDAO.shared.getUser(userId: userID) {
                        return .user(item)
                    } else {
                        return nil
                    }
                case let .link(title, url):
                    return .link(title: title, url: url)
                case let .dapp(name):
                    let dapp = DispatchQueue.main.sync {
                        Web3Chain.all.flatMap(\.dapps)
                    }.first { dapp in
                        dapp.name == name
                    }
                    if let dapp {
                        return .dapp(app: dapp)
                    } else {
                        return nil
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
        cell.maxCellWidth = collectionView.frame.width - groupHorizontalMargin * 2
        cell.size = .large
        let viewModel = viewModels[indexPath.item]
        switch viewModel.content {
        case let .mixinToken(token):
            cell.setImage { iconView in
                iconView.setIcon(token: token)
            }
        case let .user(item):
            cell.setAvatar { imageView in
                imageView.setImage(with: item)
            }
        case .link:
            cell.setImage { iconView in
                iconView.image = R.image.recent_search_link()
            }
        case let .dapp(app):
            cell.setImage { iconView in
                iconView.sd_setImage(with: app.iconURL)
            }
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
        let parent = parent as? ExploreAggregatedSearchViewController
        let viewModel = viewModels[indexPath.item]
        switch viewModel.content {
        case let .mixinToken(token):
            parent?.pushTokenViewController(token: token)
        case let .user(item):
            parent?.pushConversationViewController(userItem: item)
        case let .link(url):
            if let container = UIApplication.homeContainerViewController {
                let context = MixinWebViewController.Context(conversationId: "", initialUrl: url, saveAsRecentSearch: true)
                container.presentWebViewController(context: context)
            }
        case let .dapp(app):
            parent?.presentDapp(app: app)
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
            case mixinToken(MixinTokenItem)
            case user(UserItem)
            case link(URL)
            case dapp(Web3Dapp)
        }
        
        let content: Content
        let title: String
        let subtitle: String
        let subtitleColor: MarketColor?
        
        static func mixinToken(_ token: MixinTokenItem) -> RecentSearchViewModel {
            RecentSearchViewModel(
                content: .mixinToken(token),
                title: token.symbol,
                subtitle: token.localizedUSDChange,
                subtitleColor: .byValue(token.decimalUSDChange)
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
        
        static func link(title: String, url: URL) -> RecentSearchViewModel {
            RecentSearchViewModel(
                content: .link(url),
                title: title,
                subtitle: url.host ?? url.absoluteString,
                subtitleColor: nil
            )
        }
        
        static func dapp(app: Web3Dapp) -> RecentSearchViewModel {
            RecentSearchViewModel(
                content: .dapp(app),
                title: app.name,
                subtitle: app.host,
                subtitleColor: nil
            )
        }
        
    }
    
}
