import UIKit
import Photos
import PhotosUI

class PhotoInputViewController: UIViewController, ConversationInputAccessible {
    
    enum Section: Int, CaseIterable {
        case allPhotos = 0
        case smartAlbums
        case userCollections
    }
    
    @IBOutlet weak var albumsCollectionView: UICollectionView!
    @IBOutlet weak var albumsCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var limitedAuthorizationControlWrapperView: UIView!
    
    var isAuthorizationLimited = false {
        didSet {
            loadViewIfNeeded()
            limitedAuthorizationControlWrapperView.isHidden = !isAuthorizationLimited
        }
    }
    
    private var allPhotos: PHFetchResult<PHAsset>?
    private var smartAlbums: PHFetchResult<PHAssetCollection>?
    private var sortedSmartAlbums: [PHAssetCollection]?
    private var userCollections: PHFetchResult<PHCollection>?
    private var gridViewController: PhotoInputGridViewController!
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        albumsCollectionView.dataSource = self
        albumsCollectionView.delegate = self
        DispatchQueue.global().async { [weak self] in
            let allPhotos: PHFetchResult<PHAsset>?
            if let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject {
                allPhotos = PHAsset.fetchAssets(in: collection, options: nil)
            } else {
                allPhotos = nil
            }
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = segue.destination as? PhotoInputGridViewController {
            vc.fetchResult = allPhotos
            gridViewController = vc
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previous = previousTraitCollection, previous.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else {
            return
        }
        albumsCollectionLayout.invalidateLayout()
        albumsCollectionView.reloadData()
    }
    
    @IBAction func pickFromLibrary(_ sender: Any) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func managePhotoAuthorization(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.select_more_photos(), style: .default, handler: { _ in
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.change_settings(), style: .default, handler: { _ in
            UIApplication.openAppSettings()
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func reloadGrid(at indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            gridViewController.firstCellIsCamera = true
            gridViewController.fetchResult = allPhotos
        case .smartAlbums:
            gridViewController.firstCellIsCamera = false
            if let collection = sortedSmartAlbums?[indexPath.row] {
                gridViewController.fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            }
        case .userCollections:
            gridViewController.firstCellIsCamera = false
            if let collection = userCollections?[indexPath.row] as? PHAssetCollection {
                gridViewController.fetchResult = PHAsset.fetchAssets(in: collection, options: nil)
            } else {
                gridViewController.fetchResult = nil
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
            cell.textLabel.text = R.string.localizable.all_photos()
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
            if let allPhotos = self.allPhotos, let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                self.allPhotos = changeDetails.fetchResultAfterChanges
            }
            if let smartAlbums = self.smartAlbums, let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
                self.smartAlbums = changeDetails.fetchResultAfterChanges
                self.sortedSmartAlbums = sortedAssetCollections(from: smartAlbums)
            }
            if let userCollections = self.userCollections, let changeDetails = changeInstance.changeDetails(for: userCollections) {
                self.userCollections = changeDetails.fetchResultAfterChanges
            }
        }
    }
    
}

extension PhotoInputViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true) {
            guard let provider = results.first?.itemProvider else {
                return
            }
            let vc = R.storyboard.chat.media_preview()!
            guard vc.canLoad(itemProvider: provider) else {
                showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_share_content())
                return
            }
            vc.load(itemProvider: provider)
            vc.conversationInputViewController = self.conversationInputViewController
            vc.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
            vc.modalPresentationStyle = .custom
            self.present(vc, animated: true, completion: nil)
        }
    }
    
}

fileprivate let collectionSubtypeOrder: [PHAssetCollectionSubtype: Int] = {
    var idx = -1
    var autoIncrement: Int {
        idx += 1
        return idx
    }
    return [
        .smartAlbumFavorites: autoIncrement,
        .smartAlbumVideos: autoIncrement,
        .smartAlbumScreenshots: autoIncrement,
        .smartAlbumSelfPortraits: autoIncrement,
        .smartAlbumPanoramas: autoIncrement,
        .smartAlbumSlomoVideos: autoIncrement,
        .smartAlbumTimelapses: autoIncrement,
        .smartAlbumAnimated: autoIncrement
    ]
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
