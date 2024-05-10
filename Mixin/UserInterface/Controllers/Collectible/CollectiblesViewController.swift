import UIKit
import MixinServices

final class CollectiblesViewController: UIViewController {
    
    private enum Item {
        
        case hash(String)
        case full(InscriptionItem)
        
        var inscriptionHash: String {
            switch self {
            case .hash(let hash):
                hash
            case .full(let item):
                item.inscriptionHash
            }
        }
        
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reloadItem(_:)),
                                               name: RefreshInscriptionJob.didFinishedNotification,
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
            let itemWidth = floor((width - interitemSpacing) / 2)
            let itemHeight = ceil(itemWidth / 160 * 216)
            collectionViewLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            collectionViewLayout.invalidateLayout()
        }
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @objc private func reloadItem(_ notification: Notification) {
        guard let item = notification.userInfo?[RefreshInscriptionJob.dataUserInfoKey] as? InscriptionItem else {
            return
        }
        if let index = items.firstIndex(where: { $0.inscriptionHash == item.inscriptionHash }) {
            items[index] = .full(item)
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.reloadItems(at: [indexPath])
        }
    }
    
    private func reloadData() {
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
            cell.contentImageView.image = R.image.inscription_intaglio()
            cell.contentImageView.contentMode = .center
            cell.titleLabel.text = ""
            cell.subtitleLabel.text = ""
        case .full(let data):
            if let url = data.imageContentURL {
                cell.contentImageView.image = nil
                cell.contentImageView.contentMode = .scaleAspectFill
                cell.contentImageView.sd_setImage(with: url)
            } else {
                cell.contentImageView.image = R.image.inscription_intaglio()
                cell.contentImageView.contentMode = .center
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

extension CollectiblesViewController: HomeTabBarControllerChild {
    
    func viewControllerDidSwitchToFront() {
        reloadData()
    }
    
}
