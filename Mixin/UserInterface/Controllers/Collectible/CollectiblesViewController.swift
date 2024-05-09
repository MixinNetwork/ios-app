import UIKit
import MixinServices

final class CollectiblesViewController: UIViewController {
    
    private enum Item {
        case hash(String)
        case full(InscriptionItem)
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    private let interitemSpacing: CGFloat = 15
    
    private var items: [Item] = []
    private var lastLayoutWidth: CGFloat?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionViewLayout.minimumInteritemSpacing = interitemSpacing
        collectionViewLayout.minimumLineSpacing = 15
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 0, right: 20)
        collectionView.register(R.nib.collectibleCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        DispatchQueue.global().async {
            let partials = InscriptionDAO.shared.allPartialInscriptions()
            let items: [Item] = partials.map { partial in
                if let data = partial.asInscriptionItem() {
                    .full(data)
                } else {
                    .hash(partial.inscriptionHash)
                }
            }
            DispatchQueue.main.async {
                self.items = items
                self.collectionView.reloadData()
                self.collectionView.checkEmpty(dataCount: items.count,
                                               text: R.string.localizable.no_collectibles(),
                                               photo: R.image.emptyIndicator.ic_shared_media()!)
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
            let itemWidth = floor((width - interitemSpacing) / 2)
            let itemHeight = ceil(itemWidth / 160 * 216)
            collectionViewLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            collectionViewLayout.invalidateLayout()
        }
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
}

extension CollectiblesViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.collectible, for: indexPath)!
        let item = items[indexPath.item]
        switch item {
        case .hash:
            // Placeholder is set in `prepareForReuse`
            break
        case .full(let data):
            cell.contentImageView.sd_setImage(with: data.imageContentURL) { _, _, _, _ in
                cell.contentImageView.contentMode = .scaleAspectFill
            }
            cell.titleLabel.text = data.collectionName
            cell.subtitleLabel.text = "#\(data.sequence)"
        }
        return cell
    }
    
}

extension CollectiblesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = items[indexPath.item]
        let preview = switch item {
        case .full(let item):
            InscriptionViewController(source: .collectible(inscriptionHash: item.inscriptionHash),
                                      inscription: item,
                                      isMine: true)
        case .hash(let hash):
            InscriptionViewController(source: .collectible(inscriptionHash: hash), 
                                      inscription: nil,
                                      isMine: true)
        }
        navigationController?.pushViewController(preview, animated: true)
    }
    
}
