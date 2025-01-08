import UIKit
import Photos
import MobileCoreServices
import MixinServices

class PickerViewController: UIViewController, MixinNavigationAnimating {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    @IBOutlet weak var showActivityIndicatorWrapperConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideActivityIndicatorWrapperConstraint: NSLayoutConstraint!
    @IBOutlet weak var safeAreaTopPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        return options
    }()
    private let utiCheckingImageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        return options
    }()
    
    private lazy var itemSize: CGSize = {
        let rowCount = floor(UIScreen.main.bounds.size.width / 90)
        let itemWidth = (UIScreen.main.bounds.size.width - rowCount * 1) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }()
    
    private var showImageOnly = false
    private var collection: PHAssetCollection?
    private var assets = PHFetchResult<PHAsset>()
    private var scrollToBottom = false
    private var scrollToOffset = CGPoint.zero
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    class func instance(collection: PHAssetCollection? = nil, showImageOnly: Bool, scrollToOffset: CGPoint) -> UIViewController {
        let vc = R.storyboard.photo.picker()!
        if let collection = collection {
            vc.collection = collection
        } else {
            vc.collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject
        }
        vc.scrollToOffset = scrollToOffset
        vc.showImageOnly = showImageOnly
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = collection?.localizedTitle
        navigationItem.rightBarButtonItem = .button(
            title: R.string.localizable.cancel(),
            target: self,
            action: #selector(cancel(_:))
        )
        let collection = self.collection
        let showImageOnly = self.showImageOnly
        DispatchQueue.global().async { [weak self] in
            let assets: PHFetchResult<PHAsset>
            if let collection = collection {
                let options = PHFetchOptions()
                if showImageOnly {
                    options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                }
                assets = PHAsset.fetchAssets(in: collection, options: options)
            } else {
                assets = PHFetchResult<PHAsset>()
            }
            guard let weakSelf = self else {
                return
            }
            PHPhotoLibrary.shared().register(weakSelf)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.stopAcitivityIndicator()
                weakSelf.assets = assets
                weakSelf.collectionView?.reloadData()
                weakSelf.view.setNeedsLayout()
                weakSelf.view.layoutIfNeeded()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !scrollToBottom && assets.count > 0 {
            scrollToBottom = true
            if scrollToOffset.y > 0 {
                collectionView?.contentOffset = scrollToOffset
            } else {
                collectionView?.scrollToItem(at: IndexPath(row: assets.count - 1, section: 0), at: .bottom, animated: false)
            }
        }
    }
    
    @objc private func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    private func stopAcitivityIndicator() {
        activityIndicator.stopAnimating()
        showActivityIndicatorWrapperConstraint.priority = .defaultLow
        hideActivityIndicatorWrapperConstraint.priority = .defaultHigh
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
}

extension PickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.picker, for: indexPath)!
        let asset = assets[indexPath.row]
        cell.localIdentifier = asset.localIdentifier
        let targetSize = CGSize(width: cell.thumbImageView.frame.size.width * 2, height: cell.thumbImageView.frame.size.height * 2)
        cell.requestId = PHCachingImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageRequestOptions) { (image, _) in
            guard cell.localIdentifier == asset.localIdentifier else {
                return
            }
            cell.thumbImageView.image = image
        }
        if asset.mediaType == .video {
            cell.gifLabel.isHidden = true
            cell.videoImageView.isHidden = false
            cell.durationLabel.text = mediaDurationFormatter.string(from: asset.duration)
            cell.fileTypeView.isHidden = false
        } else {
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: utiCheckingImageRequestOptions, resultHandler: { (_, uti, _, _) in
                if let uti, let type = UTType(uti), type.conforms(to: .gif) {
                    cell.gifLabel.isHidden = false
                    cell.videoImageView.isHidden = true
                    cell.durationLabel.text = nil
                    cell.fileTypeView.isHidden = false
                } else {
                    cell.fileTypeView.isHidden = true
                }
            })
        }
        return cell
    }
    
}

extension PickerViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        navigationController?.dismiss(animated: true, completion: nil)
        if let delegate = (navigationController as? PhotoAssetPickerNavigationController)?.pickerDelegate {
            let asset = assets[indexPath.row]
            delegate.pickerController(self, contentOffset: collectionView.contentOffset, didFinishPickingMediaWithAsset: asset)
        }
    }
    
}

extension PickerViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return itemSize
    }
    
}

extension PickerViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let collectionView = collectionView else {
            return
        }
        DispatchQueue.main.sync {
            if let collection = collection, let albumChanges = changeInstance.changeDetails(for: collection), let newCollection = albumChanges.objectAfterChanges {
                self.collection = newCollection
                self.title = newCollection.localizedTitle
            }
            if let changes = changeInstance.changeDetails(for: assets) {
                assets = changes.fetchResultAfterChanges
                if changes.hasIncrementalChanges {
                    collectionView.performBatchUpdates({
                        if let removed = changes.removedIndexes, removed.count > 0 {
                            collectionView.deleteItems(at: removed.map{ IndexPath(item: $0, section:0) })
                        }
                        if let inserted = changes.insertedIndexes, inserted.count > 0 {
                            collectionView.insertItems(at: inserted.map{ IndexPath(item: $0, section:0) })
                        }
                        if let changed = changes.changedIndexes, changed.count > 0 {
                            collectionView.reloadItems(at: changed.map{ IndexPath(item: $0, section:0) })
                        }
                        changes.enumerateMoves { fromIndex, toIndex in
                            collectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
                                                    to: IndexPath(item: toIndex, section: 0))
                        }
                    })
                } else {
                    collectionView.reloadData()
                }
            }
        }
    }
    
}
