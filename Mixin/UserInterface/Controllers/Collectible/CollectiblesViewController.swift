import UIKit
import MixinServices

final class CollectiblesViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    private let interitemSpacing: CGFloat = 15
    private let hiddenSearchTopMargin: CGFloat = -28
    
    private weak var searchViewController: UIViewController?
    private weak var searchViewCenterYConstraint: NSLayoutConstraint?
    
    private var items: [InscriptionOutput] = []
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
            let itemWidth = floor((width - interitemSpacing) / 2)
            let itemHeight = ceil(itemWidth / 160 * 216)
            collectionViewLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            collectionViewLayout.invalidateLayout()
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
    
    @objc private func reloadItem(_ notification: Notification) {
        guard let newItem = notification.userInfo?[RefreshInscriptionJob.UserInfoKey.item] as? InscriptionItem else {
            return
        }
        if let index = items.firstIndex(where: { $0.inscriptionHash == newItem.inscriptionHash }) {
            items[index] = items[index].replacing(inscription: newItem)
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.reloadItems(at: [indexPath])
        }
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async {
            let items = InscriptionDAO.shared.allInscriptionOutputs()
            DispatchQueue.main.async {
                self.items = items
                self.collectionView.reloadData()
                self.collectionView.checkEmpty(dataCount: items.count,
                                               text: R.string.localizable.no_collectibles(),
                                               photo: R.image.inscription_relief()!)
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
        cell.render(item: item)
        return cell
    }
    
}

extension CollectiblesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = items[indexPath.item]
        let preview = InscriptionViewController(output: item)
        navigationController?.pushViewController(preview, animated: true)
    }
    
}

extension CollectiblesViewController: HomeTabBarControllerChild {
    
    func viewControllerDidSwitchToFront() {
        reloadData()
    }
    
}
