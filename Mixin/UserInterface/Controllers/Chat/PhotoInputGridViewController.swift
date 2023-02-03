import UIKit
import Photos
import MobileCoreServices
import MixinServices

protocol PhotoInputGridViewControllerDelegate: AnyObject {
    func photoInputGridViewController(_ controller: PhotoInputGridViewController, didSelect asset: PHAsset)
    func photoInputGridViewController(_ controller: PhotoInputGridViewController, didDeselect asset: PHAsset)
    func photoInputGridViewControllerDidTapCamera(_ controller: PhotoInputGridViewController)
}

class PhotoInputGridViewController: UIViewController, ConversationAccessible, ConversationInputAccessible {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    weak var delegate: PhotoInputGridViewControllerDelegate?
    weak var photoInputViewController: PhotoInputViewController?
    
    var fetchResult: PHFetchResult<PHAsset>? {
        didSet {
            guard isViewLoaded else {
                return
            }
            collectionView.reloadData()
            collectionView.setContentOffset(.zero, animated: false)
        }
    }
    
    var firstCellIsCamera = true
    
    private let maxSelectedCount = 99
    private let interitemSpacing: CGFloat = 0
    private let columnCount: CGFloat = 3
    private let imageManager = PHCachingImageManager()
    
    private var selectedAssets: [PHAsset] {
        photoInputViewController?.selectedAssets ?? []
    }
    private lazy var imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true
        return options
    }()
    
    private var thumbnailSize = CGSize.zero
    private var previousPreheatRect = CGRect.zero
    private var availableWidth: CGFloat = 0
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
        PHPhotoLibrary.shared().register(self)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.width
            - view.safeAreaInsets.horizontal
            - collectionViewLayout.sectionInset.horizontal
        if availableWidth != width {
            availableWidth = width
            let itemLength = floor((width - (columnCount - 1) * interitemSpacing) / columnCount)
            collectionViewLayout.itemSize = CGSize(width: itemLength, height: itemLength)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        thumbnailSize = collectionViewLayout.itemSize * UIScreen.main.scale
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }
    
}

extension PhotoInputGridViewController {
    
    func updateVisibleCellBadge() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            if let asset = asset(at: indexPath), let cell = collectionView.cellForItem(at: indexPath) as? PhotoInputGridCell {
                cell.updateBadge(with: selectedAssets.firstIndex(of: asset))
            }
        }
    }
    
}

extension PhotoInputGridViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (fetchResult?.count ?? 0) + (firstCellIsCamera ? 1 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.photo_grid, for: indexPath)!
        if firstCellIsCamera && indexPath.item == 0 {
            cell.identifier = nil
            cell.imageView.contentMode = .center
            cell.imageView.image = R.image.conversation.ic_camera()
            cell.imageView.backgroundColor = R.color.camera_background()
            cell.mediaTypeView.style = .hidden
            cell.indexLabel.isHidden = true
            cell.statusImageView.isHidden = true
        } else if let asset = asset(at: indexPath) {
            cell.identifier = asset.localIdentifier
            cell.imageView.contentMode = .scaleAspectFill
            cell.imageView.backgroundColor = .background
            cell.indexLabel.isHidden = false
            cell.statusImageView.isHidden = false
            cell.updateBadge(with: selectedAssets.firstIndex(of: asset))
            imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: imageRequestOptions) { [weak cell] (image, _) in
                guard let cell = cell, cell.identifier == asset.localIdentifier else {
                    return
                }
                cell.imageView.image = image
            }
            if asset.mediaType == .video {
                cell.mediaTypeView.style = .video(duration: asset.duration)
            } else {
                if let uti = asset.value(forKey: "uniformTypeIdentifier") as? String, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
                    cell.mediaTypeView.style = .gif
                } else {
                    cell.mediaTypeView.style = .hidden
                }
            }
        }
        return cell
    }
    
}

extension PhotoInputGridViewController: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        if firstCellIsCamera && indexPath.item == 0 {
            UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
            conversationViewController?.imagePickerController.presentCamera()
            delegate?.photoInputGridViewControllerDidTapCamera(self)
        } else if let asset = asset(at: indexPath) {
            if selectedAssets.contains(asset) {
                delegate?.photoInputGridViewController(self, didDeselect: asset)
                updateVisibleCellBadge()
            } else if selectedAssets.count < maxSelectedCount {
                delegate?.photoInputGridViewController(self, didSelect: asset)
                updateVisibleCellBadge()
            }
        }
    }
    
}

extension PhotoInputGridViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let oldFetchResult = fetchResult, let changes = changeInstance.changeDetails(for: oldFetchResult) else {
            return
        }
        DispatchQueue.main.sync {
            self.fetchResult = changes.fetchResultAfterChanges
            collectionView.reloadData()
            resetCachedAssets()
        }
    }
    
}

extension PhotoInputGridViewController {
    
    private func resetCachedAssets() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = .zero
    }
    
    private func updateCachedAssets() {
        guard isViewLoaded, view.window != nil, fetchResult != nil else {
            return
        }
        let visibleRect = collectionView.bounds
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else {
            return
        }
        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap(indexPathsForElements)
            .compactMap(asset)
        let removedAssets = removedRects
            .flatMap(indexPathsForElements)
            .compactMap(asset)
        imageManager.startCachingImages(for: addedAssets,
                                        targetSize: thumbnailSize,
                                        contentMode: .aspectFill,
                                        options: nil)
        imageManager.stopCachingImages(for: removedAssets,
                                       targetSize: thumbnailSize,
                                       contentMode: .aspectFill,
                                       options: nil)
        previousPreheatRect = preheatRect
    }
    
    private func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                let rect = CGRect(x: new.origin.x,
                                  y: old.maxY,
                                  width: new.width,
                                  height: new.maxY - old.maxY)
                added.append(rect)
            }
            if old.minY > new.minY {
                let rect = CGRect(x: new.origin.x,
                                  y: new.minY,
                                  width: new.width,
                                  height: old.minY - new.minY)
                added.append(rect)
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                let rect = CGRect(x: new.origin.x,
                                  y: new.maxY,
                                  width: new.width,
                                  height: old.maxY - new.maxY)
                removed.append(rect)
            }
            if old.minY < new.minY {
                let rect = CGRect(x: new.origin.x,
                                  y: old.minY,
                                  width: new.width,
                                  height: new.minY - old.minY)
                removed.append(rect)
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
    
    private func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        return collectionViewLayout
            .layoutAttributesForElements(in: rect)?
            .map { $0.indexPath } ?? []
    }
    
    private func asset(at indexPath: IndexPath) -> PHAsset? {
        guard let fetchResult = fetchResult else {
            return nil
        }
        guard let index = fetchResultIndex(count: fetchResult.count, indexPath: indexPath) else {
            return nil
        }
        let asset = fetchResult.object(at: index)
        return asset
    }
    
    private func indexPath(fetchResultCount: Int, index: Int) -> IndexPath {
        let cameraCellFactor = firstCellIsCamera ? 1 : 0
        let item = fetchResultCount - 1 + cameraCellFactor - index
        return IndexPath(item: item, section: 0)
    }
    
    private func fetchResultIndex(count: Int, indexPath: IndexPath) -> Int? {
        if firstCellIsCamera {
            if indexPath.row == 0 && indexPath.item == 0 {
                return nil
            } else {
                return count - 1 - (indexPath.item - 1)
            }
        } else {
            return count - 1 - indexPath.item
        }
    }
    
}
