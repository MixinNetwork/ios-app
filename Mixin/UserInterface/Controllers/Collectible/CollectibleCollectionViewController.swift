import UIKit
import MixinServices

final class CollectibleCollectionViewController: UIViewController {
    
    private let collectionViewLayout = LeftAlignedCollectionViewFlowLayout()
    
    private var collection: InscriptionCollectionPreview
    private var collectionView: UICollectionView!
    private var lastLayoutWidth: CGFloat?
    private var token: MixinTokenItem?
    private var items: [InscriptionOutput] = []
    
    init(collection: InscriptionCollectionPreview) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = R.color.background()
        
        collectionViewLayout.minimumInteritemSpacing = 15
        collectionViewLayout.minimumLineSpacing = 15
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 10, left: 20, bottom: 0, right: 20)
        collectionViewLayout.headerReferenceSize = CGSize(width: view.bounds.width, height: 195)
        
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: collectionViewLayout)
        view.addSubview(collectionView)
        collectionView.backgroundColor = R.color.background()
        collectionView.snp.makeEdgesEqualToSuperview()
        self.collectionView = collectionView
        
        collectionView.register(R.nib.collectibleCell)
        collectionView.register(R.nib.collectibleCollectionHeaderView,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.dataSource = self
        collectionView.delegate = self
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData),
                                               name: OutputDAO.didSignOutputNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData),
                                               name: OutputDAO.didInsertInscriptionOutputsNotification,
                                               object: nil)
        reloadData()
        InscriptionAPI.collection(collectionHash: collection.collectionHash) { [weak self] result in
            switch result {
            case .success(let collection):
                guard let self else {
                    return
                }
                DispatchQueue.global().async {
                    InscriptionDAO.shared.save(collection: collection)
                }
                self.collection = self.collection.replacing(name: collection.name,
                                                            description: collection.description)
                let headerView = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader,
                                                                       at: IndexPath(item: 0, section: 0))
                if let view = headerView as? CollectibleCollectionHeaderView {
                    view.load(token: self.token, collection: self.collection)
                }
            case .failure:
                break
            }
        }
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
            collectionViewLayout.headerReferenceSize = CGSize(width: view.bounds.width, height: 195)
            collectionViewLayout.invalidateLayout()
        }
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [collection, weak self] in
            let token = TokenDAO.shared.tokenItem(kernelAssetID: collection.asset)
            let items = InscriptionDAO.shared.allInscriptionOutputs(collectionHash: collection.collectionHash, sortedBy: .recent)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                if items.isEmpty, let navigationController = self.navigationController {
                    let animated = navigationController.viewControllers.last == self
                    var viewControllers = navigationController.viewControllers
                    viewControllers.removeAll(where: { $0 == self })
                    navigationController.setViewControllers(viewControllers, animated: animated)
                } else {
                    self.token = token
                    self.items = items
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
}

extension CollectibleCollectionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.collectible, for: indexPath)!
        let item = items[indexPath.item]
        cell.render(item: item)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.collectible_collection, for: indexPath)!
        view.load(token: token, collection: collection)
        return view
    }
    
}

extension CollectibleCollectionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = items[indexPath.item]
        let preview = InscriptionViewController(output: item)
        navigationController?.pushViewController(preview, animated: true)
    }
    
}
