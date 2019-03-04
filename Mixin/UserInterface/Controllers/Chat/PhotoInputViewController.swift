import UIKit
import Photos

class PhotoInputViewController: UIViewController {
    
    enum Section: Int, CaseIterable {
        case allPhotos = 0
        case smartAlbums
        case userCollections
    }
    
    private static let creationDateDescendingFetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }()
    
    @IBOutlet weak var albumsCollectionView: UICollectionView!
    @IBOutlet weak var albumsCollectionLayout: UICollectionViewFlowLayout!
    
    private let cellReuseId = "album"
    
    private var allPhotos: PHFetchResult<PHAsset>
    private var smartAlbums: PHFetchResult<PHAssetCollection>
    private var sortedSmartAlbums: [PHAssetCollection]
    private var userCollections: PHFetchResult<PHCollection>
    private var gridViewController: PhotoInputGridViewController!
    
    required init?(coder aDecoder: NSCoder) {
        allPhotos = PHAsset.fetchAssets(with: PhotoInputViewController.creationDateDescendingFetchOptions)
        smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        sortedSmartAlbums = sortedAssetCollections(from: smartAlbums)
        userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        super.init(coder: aDecoder)
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        albumsCollectionLayout.estimatedItemSize = CGSize(width: 110, height: 60)
        albumsCollectionView.dataSource = self
        albumsCollectionView.delegate = self
        albumsCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .left)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = segue.destination as? PhotoInputGridViewController {
            vc.fetchResult = allPhotos
            gridViewController = vc
        }
    }
    
}

extension PhotoInputViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .allPhotos:
            return 1
        case .smartAlbums:
            return sortedSmartAlbums.count
        case .userCollections:
            return userCollections.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! PhotoInputAlbumCell
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            cell.textLabel.text = Localized.ALL_PHOTOS
        case .smartAlbums:
            cell.textLabel.text = sortedSmartAlbums[indexPath.row].localizedTitle
        case .userCollections:
            cell.textLabel.text = userCollections[indexPath.row].localizedTitle
        }
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }
    
}

extension PhotoInputViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            gridViewController.fetchResult = allPhotos
        case .smartAlbums:
            let assetCollection = sortedSmartAlbums[indexPath.row]
            gridViewController.fetchResult = PHAsset.fetchAssets(in: assetCollection, options: PhotoInputViewController.creationDateDescendingFetchOptions)
        case .userCollections:
            if let assetCollection = userCollections[indexPath.row] as? PHAssetCollection {
                gridViewController.fetchResult = PHAsset.fetchAssets(in: assetCollection, options: PhotoInputViewController.creationDateDescendingFetchOptions)
            } else {
                gridViewController.fetchResult = nil
            }
        }
    }
    
}

extension PhotoInputViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.sync {
            if let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                allPhotos = changeDetails.fetchResultAfterChanges
            }
            if let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
                smartAlbums = changeDetails.fetchResultAfterChanges
                sortedSmartAlbums = sortedAssetCollections(from: smartAlbums)
            }
            if let changeDetails = changeInstance.changeDetails(for: userCollections) {
                userCollections = changeDetails.fetchResultAfterChanges
            }
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
