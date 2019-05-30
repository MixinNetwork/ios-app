import UIKit
import Photos

class PhotoInputViewController: UIViewController {
    
    enum Section: Int, CaseIterable {
        case allPhotos = 0
        case smartAlbums
        case userCollections
    }
    
    @IBOutlet weak var albumsCollectionView: UICollectionView!
    @IBOutlet weak var albumsCollectionLayout: UICollectionViewFlowLayout!
    
    private let creationDateDescendingFetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }()
    
    private var allPhotos: PHFetchResult<PHAsset>?
    private var smartAlbums: PHFetchResult<PHAssetCollection>?
    private var sortedSmartAlbums: [PHAssetCollection]?
    private var userCollections: PHFetchResult<PHCollection>?
    private var gridViewController: PhotoInputGridViewController!
    private var previewViewController: MediaPreviewViewController!
    private var needsReload = false
    
    @IBOutlet weak var previewWrapperHeightConstraint: NSLayoutConstraint!
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = segue.destination as? PhotoInputGridViewController {
            vc.fetchResult = allPhotos
            gridViewController = vc
        } else if let vc = segue.destination as? MediaPreviewViewController {
            previewViewController = vc
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        albumsCollectionLayout.estimatedItemSize = CGSize(width: 110, height: 60)
        albumsCollectionView.dataSource = self
        albumsCollectionView.delegate = self
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needsReload {
            reloadData()
        }
    }
    
    func preview(asset: PHAsset) {
        previewWrapperHeightConstraint.constant = 276
        previewViewController.load(asset: asset)
    }
    
    func dismissPreviewIfNeeded() {
        guard isViewLoaded else {
            return
        }
        previewViewController.stopVideoPreviewIfNeeded()
        if previewWrapperHeightConstraint.constant > 0 {
            previewWrapperHeightConstraint.constant = 0
            gridViewController.removeAllSelections(animated: true)
        }
    }
    
    private func reloadGrid(at indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            gridViewController.firstCellIsCamera = true
            gridViewController.fetchResult = allPhotos
        case .smartAlbums:
            gridViewController.firstCellIsCamera = false
            if let collection = sortedSmartAlbums?[indexPath.row] {
                gridViewController.fetchResult = PHAsset.fetchAssets(in: collection, options: creationDateDescendingFetchOptions)
            }
        case .userCollections:
            gridViewController.firstCellIsCamera = false
            if let collection = userCollections?[indexPath.row] as? PHAssetCollection {
                gridViewController.fetchResult = PHAsset.fetchAssets(in: collection, options: creationDateDescendingFetchOptions)
            } else {
                gridViewController.fetchResult = nil
            }
        }
    }
    
    private func reloadData() {
        let fetchOption = self.creationDateDescendingFetchOptions
        DispatchQueue.global().async { [weak self] in
            let allPhotos = PHAsset.fetchAssets(with: fetchOption)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            let sortedSmartAlbums = sortedAssetCollections(from: smartAlbums)
            let userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
            guard let weakSelf = self else {
                return
            }
            PHPhotoLibrary.shared().register(weakSelf)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.allPhotos = allPhotos
                weakSelf.smartAlbums = smartAlbums
                weakSelf.sortedSmartAlbums = sortedSmartAlbums
                weakSelf.userCollections = userCollections
                weakSelf.albumsCollectionView.reloadData()
                let firstItem = IndexPath(item: 0, section: 0)
                weakSelf.albumsCollectionView.selectItem(at: firstItem, animated: false, scrollPosition: .left)
                weakSelf.reloadGrid(at: firstItem)
            }
        }
    }
    
}

extension PhotoInputViewController: ConversationInputInteractiveResizableViewController {
    
    var interactiveResizableScrollView: UIScrollView {
        return gridViewController.collectionView
    }
    
}

extension PhotoInputViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .allPhotos:
            return 1
        case .smartAlbums:
            return sortedSmartAlbums?.count ?? 0
        case .userCollections:
            return userCollections?.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.photo_album, for: indexPath)!
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            cell.textLabel.text = Localized.ALL_PHOTOS
        case .smartAlbums:
            cell.textLabel.text = sortedSmartAlbums?[indexPath.row].localizedTitle ?? ""
        case .userCollections:
            cell.textLabel.text = userCollections?[indexPath.row].localizedTitle ?? ""
        }
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }
    
}

extension PhotoInputViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        reloadGrid(at: indexPath)
    }
    
}

extension PhotoInputViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.sync {
            needsReload = true
        }
    }
    
}

fileprivate let collectionSubtypeOrder: [PHAssetCollectionSubtype: Int] = {
    var idx = -1
    var autoIncrement: Int {
        idx += 1
        return idx
    }
    var order: [PHAssetCollectionSubtype: Int] = [
        .smartAlbumFavorites: autoIncrement,
        .smartAlbumVideos: autoIncrement,
        .smartAlbumScreenshots: autoIncrement,
        .smartAlbumSelfPortraits: autoIncrement,
        .smartAlbumPanoramas: autoIncrement,
        .smartAlbumSlomoVideos: autoIncrement,
        .smartAlbumTimelapses: autoIncrement
    ]
    if #available(iOS 11.0, *) {
        order[.smartAlbumAnimated] = autoIncrement
    }
    return order
}()

fileprivate func sortedAssetCollections(from: PHFetchResult<PHAssetCollection>) -> [PHAssetCollection] {
    var collections = [PHAssetCollection?](repeating: nil, count: from.count)
    from.enumerateObjects { (obj, idx, nil) in
        collections[idx] = obj
    }
    return collections
        .compactMap({ $0 })
        .filter({
            collectionSubtypeOrder[$0.assetCollectionSubtype] != nil
        })
        .sorted(by: { (one, another) -> Bool in
            let oneOrder = collectionSubtypeOrder[one.assetCollectionSubtype]!
            let anotherOrder = collectionSubtypeOrder[another.assetCollectionSubtype]!
            return oneOrder < anotherOrder
        })
}
