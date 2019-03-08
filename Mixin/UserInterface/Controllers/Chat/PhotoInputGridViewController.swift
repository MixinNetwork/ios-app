import UIKit
import Photos
import MobileCoreServices

class PhotoInputGridViewController: UIViewController, ConversationAccessible {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    var fetchResult: PHFetchResult<PHAsset>? {
        didSet {
            guard isViewLoaded else {
                return
            }
            collectionView.reloadData()
            collectionView.setContentOffset(.zero, animated: false)
        }
    }
    
    private let cellReuseId = "grid"
    private let interitemSpacing: CGFloat = 0
    private let columnCount: CGFloat = 3
    private let imageManager = PHCachingImageManager()
    private let utiCheckingImageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
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
            - view.compatibleSafeAreaInsets.horizontal
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

extension PhotoInputGridViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! PhotoInputGridCell
        guard let asset = fetchResult?.object(at: indexPath.item) else {
            return cell
        }
        cell.identifier = asset.localIdentifier
        imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil) { [weak cell] (image, _) in
            guard let cell = cell, cell.identifier == asset.localIdentifier else {
                return
            }
            cell.imageView.image = image
        }
        if asset.mediaType == .video {
            cell.fileTypeWrapperView.isHidden = false
            cell.gifFileTypeView.isHidden = true
            cell.videoTypeView.isHidden = false
            cell.videoDurationLabel.text = mediaDurationFormatter.string(from: asset.duration)
        } else {
            if let uti = asset.value(forKey: "uniformTypeIdentifier") as? String, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
                cell.fileTypeWrapperView.isHidden = false
                cell.gifFileTypeView.isHidden = false
                cell.videoTypeView.isHidden = true
            } else {
                cell.fileTypeWrapperView.isHidden = true
                cell.gifFileTypeView.isHidden = true
                cell.videoTypeView.isHidden = true
            }
        }
        return cell
    }
    
}

extension PhotoInputGridViewController: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        removeAllSelections()
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        removeAllSelections()
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        if let asset = fetchResult?.object(at: indexPath.row) {
            let vc = AssetSendViewController.instance(asset: asset, dataSource: dataSource)
            navigationController?.pushViewController(vc, animated: true)
        }
        return true
    }
    
}

extension PhotoInputGridViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult = fetchResult, let changes = changeInstance.changeDetails(for: fetchResult) else {
            return
        }
        DispatchQueue.main.sync {
            if changes.hasIncrementalChanges {
                collectionView.performBatchUpdates({
                    self.fetchResult = changes.fetchResultAfterChanges
                    if let removed = changes.removedIndexes, !removed.isEmpty {
                        let indexPaths = removed.map({ IndexPath(item: $0, section: 0) })
                        collectionView.deleteItems(at: indexPaths)
                    }
                    if let inserted = changes.insertedIndexes, !inserted.isEmpty {
                        let indexPaths = inserted.map({ IndexPath(item: $0, section: 0) })
                        collectionView.insertItems(at: indexPaths)
                    }
                    changes.enumerateMoves({ (from, to) in
                        self.collectionView.moveItem(at: IndexPath(item: from, section: 0),
                                                     to: IndexPath(item: to, section: 0))
                    })
                    if let changed = changes.changedIndexes, !changed.isEmpty {
                        let indexPaths = changed.map({ IndexPath(item: $0, section: 0) })
                        collectionView.reloadItems(at: indexPaths)
                    }
                })
            } else {
                self.fetchResult = changes.fetchResultAfterChanges
                collectionView.reloadData()
            }
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
        guard isViewLoaded, view.window != nil, let fetchResult = fetchResult else {
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
            .map { fetchResult.object(at: $0.item) }
        let removedAssets = removedRects
            .flatMap(indexPathsForElements)
            .map { fetchResult.object(at: $0.item) }
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
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)!
        return allLayoutAttributes.map { $0.indexPath }
    }
    
    private func removeAllSelections() {
        collectionView.indexPathsForSelectedItems?.forEach({ (indexPath) in
            collectionView.deselectItem(at: indexPath, animated: false)
        })
    }
    
}
