import UIKit
import MixinServices

final class CollectiblesViewController: UIViewController {
    
    private enum Content {
        case item
        case collection
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var contentSwitchWrapperView: UIView!
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var collectionImageView: UIImageView!
    @IBOutlet weak var showItemButton: UIButton!
    @IBOutlet weak var showCollectionButton: UIButton!
    @IBOutlet weak var sortButton: CollectiblesSortButton!
    
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private weak var searchViewController: UIViewController?
    private weak var searchViewCenterYConstraint: NSLayoutConstraint?
    
    private var items: [InscriptionOutput] = []
    private var collections: [InscriptionCollectionPreview] = []
    private var order: InscriptionDAO.Ordering = .recent
    private var content: Content = .item
    private var lastLayoutWidth: CGFloat?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sortButton.semanticContentAttribute = .forceRightToLeft
        contentSwitchWrapperView.layer.cornerRadius = 19
        contentSwitchWrapperView.layer.borderWidth = 1
        contentSwitchWrapperView.layer.masksToBounds = true
        showItemButton.isHighlighted = true
        sortButton.layer.cornerRadius = 19
        sortButton.layer.borderWidth = 1
        sortButton.layer.masksToBounds = true
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
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 10, left: 20, bottom: 0, right: 20)
        collectionView.register(R.nib.collectibleCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadCollection(_:)),
                                               name: InscriptionDAO.didSaveCollectionNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadItem(_:)),
                                               name: RefreshInscriptionJob.didFinishedNotification,
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
    
    @IBAction func searchCollectibles(_ sender: Any) {
        let searchViewController = SearchCollectibleViewController()
        addChild(searchViewController)
        searchViewController.view.alpha = 0
        view.addSubview(searchViewController.view)
        searchViewController.view.snp.makeConstraints { make in
            make.size.centerX.equalToSuperview()
        }
        let searchViewCenterYConstraint = searchViewController.view.centerYAnchor
            .constraint(equalTo: view.centerYAnchor, constant: hiddenSearchTopMargin)
        searchViewCenterYConstraint.isActive = true
        searchViewController.didMove(toParent: self)
        view.layoutIfNeeded()
        searchViewCenterYConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            searchViewController.view.alpha = 1
        }
        self.searchViewController = searchViewController
        self.searchViewCenterYConstraint = searchViewCenterYConstraint
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func openSettings(_ sender: Any) {
        let settings = SettingsViewController.instance()
        navigationController?.pushViewController(settings, animated: true)
    }
    
    @IBAction func showItems(_ sender: Any) {
        itemImageView.tintColor = R.color.theme()!
        collectionImageView.tintColor = R.color.icon_tint()!
        show(content: .item)
    }
    
    @IBAction func showCollections(_ sender: Any) {
        itemImageView.tintColor = R.color.icon_tint()!
        collectionImageView.tintColor = R.color.theme()!
        show(content: .collection)
    }
    
    func cancelSearching(animated: Bool) {
        guard let searchViewController, let searchViewCenterYConstraint else {
            return
        }
        let removeSearch = {
            searchViewController.willMove(toParent: nil)
            searchViewController.view.removeFromSuperview()
            searchViewController.removeFromParent()
        }
        if animated {
            searchViewCenterYConstraint.constant = hiddenSearchTopMargin
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                searchViewController.view.alpha = 0
            } completion: { _ in
                removeSearch()
            }
        } else {
            removeSearch()
        }
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
                items = InscriptionDAO.shared.allInscriptionOutputs(sortedBy: order)
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
    
    private func show(content: Content) {
        self.content = content
        reloadData()
    }
    
    private func sort(by order: InscriptionDAO.Ordering) {
        self.order = order
        switch order {
        case .recent:
            sortButton.setTitle(R.string.localizable.recent(), for: .normal)
        case .alphabetical:
            sortButton.setTitle(R.string.localizable.alphabetical(), for: .normal)
        }
        reloadData()
    }
    
    private func updateOutlineColors() {
        contentSwitchWrapperView.layer.borderColor = R.color
            .collectible_outline()!
            .resolvedColor(with: traitCollection)
            .cgColor
        sortButton.updateColors()
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
            let container = ContainerViewController.instance(viewController: preview, title: "")
            navigationController?.pushViewController(container, animated: true)
        }
    }
    
}

extension CollectiblesViewController: HomeTabBarControllerChild {
    
    func viewControllerDidSwitchToFront() {
        reloadData()
    }
    
}
