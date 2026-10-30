import UIKit
import MixinServices

final class CollectiblesViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var contentSegmentedControl: OutlineSegmentedControl!
    @IBOutlet weak var sortButton: ConfigurationBasedOutlineButton!
    
    private var order = AppGroupUserDefaults.User.collectibleOrdering
    private var content = AppGroupUserDefaults.User.collectibleContent
    private var items: [InscriptionOutput] = []
    private var collections: [InscriptionCollectionPreview] = []
    private var lastLayoutWidth: CGFloat?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.collectibles()
        navigationItem.standardAppearance = .transparent
        navigationItem.scrollEdgeAppearance = .transparent
        navigationItem.compactAppearance = .transparent
        navigationItem.compactScrollEdgeAppearance = .transparent
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.collectibles(),
            wallet: .privacy
        )
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_search(),
            target: self,
            action: #selector(search(_:)),
        )
        contentSegmentedControl.items = [
            R.image.collectible_tab_item()!,
            R.image.collectible_tab_collection()!,
        ]
        switch content {
        case .item:
            contentSegmentedControl.selectItem(at: 0)
        case .collection:
            contentSegmentedControl.selectItem(at: 1)
        }
        updateOrderingSelection()
        sortButton.menu = UIMenu(children: [
            UIAction(
                title: R.string.localizable.recent(),
                image: R.image.order_recent(),
                handler: { [weak self] _ in self?.sort(by: .recent) }
            ),
            UIAction(
                title: R.string.localizable.alphabetical(),
                image: R.image.order_alphabetical(),
                handler: { [weak self] _ in self?.sort(by: .alphabetical) }
            ),
        ])
        updateOutlineColors()
        collectionViewLayout.minimumInteritemSpacing = 15
        collectionViewLayout.minimumLineSpacing = 15
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 10, left: 20, bottom: 20, right: 20)
        collectionView.register(R.nib.collectibleCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadCollection(_:)),
                                               name: InscriptionDAO.didSaveCollectionNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadItem(_:)),
                                               name: RefreshInscriptionJob.didFinishNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData),
                                               name: OutputDAO.didSignOutputNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData),
                                               name: OutputDAO.didInsertInscriptionOutputsNotification,
                                               object: nil)
        reloadData()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.width
        - view.safeAreaInsets.horizontal
        - collectionViewLayout.sectionInset.horizontal
        if lastLayoutWidth != width {
            lastLayoutWidth = width
            let itemWidth = floor((width - collectionViewLayout.minimumInteritemSpacing) / 2)
            let itemHeight = ceil(itemWidth / 160 * 216)
            collectionViewLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            collectionViewLayout.invalidateLayout()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateOutlineColors()
        }
    }
    
    @IBAction func segmentValueChanged(_ control: OutlineSegmentedControl) {
        let content: CollectibleDisplayContent
        switch control.selectedItemIndex {
        case 0:
            content = .item
        case 1:
            content = .collection
        default:
            return
        }
        self.content = content
        AppGroupUserDefaults.User.collectibleContent = content
        reloadData()
    }
    
    @IBAction func search(_ sender: Any) {
        let search = SearchCollectibleViewController()
        navigationController?.pushViewController(search, animated: true)
    }
    
    @objc private func reloadCollection(_ notification: Notification) {
        guard content == .collection else {
            return
        }
        reloadData()
    }
    
    @objc private func reloadItem(_ notification: Notification) {
        guard
            content == .item,
            let newItem = notification.userInfo?[RefreshInscriptionJob.UserInfoKey.item] as? InscriptionItem,
            let index = items.firstIndex(where: { $0.inscriptionHash == newItem.inscriptionHash })
        else {
            return
        }
        items[index] = items[index].replacing(inscription: newItem)
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.reloadItems(at: [indexPath])
    }
    
    @objc private func reloadData() {
        let order = self.order
        let content = self.content
        DispatchQueue.global().async {
            let items: [InscriptionOutput]
            let collections: [InscriptionCollectionPreview]
            switch content {
            case .item:
                items = InscriptionDAO.shared.allInscriptionOutputs(
                    collectionHash: nil,
                    sortedBy: order,
                    limit: nil,
                )
                collections = []
            case .collection:
                items = []
                collections = InscriptionDAO.shared.allCollections(sortedBy: order)
            }
            DispatchQueue.main.async {
                guard order == self.order, content == self.content else {
                    return
                }
                self.items = items
                self.collections = collections
                self.collectionView.reloadData()
                let count = switch content {
                case .item:
                    items.count
                case .collection:
                    collections.count
                }
                self.collectionView.checkEmpty(dataCount: count,
                                               text: R.string.localizable.no_collectibles(),
                                               photo: R.image.inscription_relief()!)
            }
        }
    }
    
    private func sort(by order: CollectibleDisplayOrdering) {
        self.order = order
        AppGroupUserDefaults.User.collectibleOrdering = order
        updateOrderingSelection()
        reloadData()
    }
    
    private func updateOutlineColors() {
        contentSegmentedControl.layer.borderColor = R.color
            .outline_primary()!
            .resolvedColor(with: traitCollection)
            .cgColor
    }
    
    private func updateOrderingSelection() {
        let title = switch order {
        case .recent:
            R.string.localizable.recent()
        case .alphabetical:
            R.string.localizable.alphabetical()
        }
        sortButton.configuration?.attributedTitle = AttributedString(
            string: title,
            scalingByFontSize: 14,
        )
    }
    
}

extension CollectiblesViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch content {
        case .item:
            items.count
        case .collection:
            collections.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.collectible, for: indexPath)!
        switch content {
        case .item:
            let item = items[indexPath.item]
            cell.render(item: item)
        case .collection:
            let collection = collections[indexPath.item]
            cell.render(collection: collection)
        }
        return cell
    }
    
}

extension CollectiblesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        switch content {
        case .item:
            let item = items[indexPath.item]
            if item.inscription == nil, let hash = item.output.inscriptionHash, !hash.isEmpty {
                let job = RefreshInscriptionJob(inscriptionHash: hash)
                ConcurrentJobQueue.shared.addJob(job: job)
            }
        case .collection:
            break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch content {
        case .item:
            let item = items[indexPath.item]
            let preview = InscriptionViewController(output: item)
            navigationController?.pushViewController(preview, animated: true)
        case .collection:
            let collection = collections[indexPath.item]
            let preview = CollectibleCollectionViewController(collection: collection)
            navigationController?.pushViewController(preview, animated: true)
        }
    }
    
}
