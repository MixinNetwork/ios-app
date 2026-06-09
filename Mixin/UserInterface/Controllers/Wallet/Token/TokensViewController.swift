import UIKit
import MixinServices

class TokensViewController: UIViewController {
    
    enum Section: Int, CaseIterable {
        case overview
        case tokens
    }
    
    private(set) weak var collectionView: UICollectionView!
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = R.color.background_secondary()
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { sectionIndex, environment in
                switch Section(rawValue: sectionIndex)! {
                case .overview:
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(216))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    return section
                case .tokens:
                    var config = UICollectionLayoutListConfiguration(appearance: .plain)
                    config.showsSeparators = false
                    config.backgroundColor = .clear
                    config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                        self?.hideTokenAction(indexPath: indexPath)
                    }
                    config.headerMode = .none
                    config.footerMode = .none
                    config.headerTopPadding = 0
                    let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
                    section.interGroupSpacing = 20
                    section.decorationItems = {
                        let background: NSCollectionLayoutDecorationItem = .background(
                            elementKind: TradeSectionBackgroundView.elementKind
                        )
                        background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                        return [background]
                    }()
                    return section
                }
            },
            configuration: config
        )
        layout.register(
            TradeSectionBackgroundView.self,
            forDecorationViewOfKind: TradeSectionBackgroundView.elementKind
        )
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.register(R.nib.walletOverviewCell)
        collectionView.register(R.nib.tokenCell)
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        self.collectionView = collectionView
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updateCollectionViewInsets()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCollectionViewInsets()
    }
    
    func hideTokenAction(indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        nil
    }
    
    private func updateCollectionViewInsets() {
        if view.safeAreaInsets.bottom < 10 {
            collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        } else {
            collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        }
    }
    
}

extension TokensViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}
