import UIKit
import Photos
import MixinServices

protocol MediasPreviewViewControllerDelegate: AnyObject {
    func mediasPreviewViewController(_ controller: MediasPreviewViewController, didSend assets: [PHAsset])
    func mediasPreviewViewController(_ controller: MediasPreviewViewController, didRemove asset: PHAsset)
    func mediasPreviewViewController(_ controller: MediasPreviewViewController, didSelectAssetAt index: Int)
    func mediasPreviewViewController(_ controller: MediasPreviewViewController, didCancelSend assets: [PHAsset])
}

final class MediasPreviewViewController: UIViewController {
    
    let viewHeight: CGFloat = 224
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var sendButton: UIButton!
    
    weak var delegate: MediasPreviewViewControllerDelegate?
    weak var gridViewController: PhotoInputGridViewController?
    
    private var cellSizeCache = [String: CGSize]()
    private var isAddingAsset = false
    private var isRemovingAsset = false
    private var selectedAssets: [PHAsset] {
        gridViewController?.selectedAssets ?? []
    }
    private var assets = [PHAsset]() {
        didSet {
            sendButton.setTitle(R.string.localizable.chat_media_send_count(assets.count), for: .normal)
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        delegate?.mediasPreviewViewController(self, didCancelSend: assets)
    }
    
    @IBAction func sendAction(_ sender: Any) {
        delegate?.mediasPreviewViewController(self, didSend: assets)
    }
    
}

extension MediasPreviewViewController {
    
    func add(_ asset: PHAsset) {
        isAddingAsset = true
        assets = selectedAssets
        UIView.performWithoutAnimation(collectionView.reloadData)
        collectionView.scrollToItem(at: IndexPath(item: assets.count - 1, section: 0),
                                    at: .centeredHorizontally,
                                    animated: true)
    }
    
    func remove(_ asset: PHAsset) {
        guard let index = assets.firstIndex(of: asset) else {
            return
        }
        cellSizeCache.removeValue(forKey: asset.localIdentifier)
        let indexPath = IndexPath(item: index, section: 0)
        let removeInvisibleCell = !collectionView.indexPathsForVisibleItems.contains(indexPath)
        if isRemovingAsset || removeInvisibleCell {
            assets = selectedAssets
            collectionView.reloadData()
        } else if let cell = collectionView.cellForItem(at: indexPath) {
            removeMediaAnimated(asset: asset, cell: cell)
        }
    }
    
    func removeAllAssets() {
        cellSizeCache.removeAll()
        assets.removeAll()
        collectionView.reloadData()
    }
    
    func updateAssets() {
        cellSizeCache.removeAll()
        assets = selectedAssets
        collectionView.reloadData()
    }
    
}

extension MediasPreviewViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.selected_media, for: indexPath)!
        if indexPath.item < assets.count {
            let asset = assets[indexPath.item]
            cell.load(asset: asset, size: cellSizeForItemAt(indexPath.item))
            cell.onRemove = { [weak self] in
                guard let self = self else {
                    return
                }
                self.removeMediaAnimated(asset: asset, cell: cell)
                self.delegate?.mediasPreviewViewController(self, didRemove: asset)
            }
        }
        return cell
    }
    
}

extension MediasPreviewViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        cellSizeForItemAt(indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if isAddingAsset && indexPath.item == assets.count - 1 {
            addedMediaWillDisplay(cell)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.mediasPreviewViewController(self, didSelectAssetAt: indexPath.item)
    }
    
}

extension MediasPreviewViewController {
    
    private func cellSizeForItemAt(_ index: Int) -> CGSize {
        guard index < assets.count else {
            return .zero
        }
        let asset = assets[index]
        if let size = cellSizeCache[asset.localIdentifier] {
            return size
        } else {
            let height: CGFloat = 160
            let width: CGFloat
            let ratio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
            if ratio > 1 {
                width = height / 3 * 4
            } else if ratio < 1 {
                width = height / 4 * 3
            } else {
                width = height
            }
            let size = CGSize(width: ceil(width), height: ceil(height))
            cellSizeCache[asset.localIdentifier] = size
            return size
        }
    }
    
    private func removeMediaAnimated(asset: PHAsset, cell: UICollectionViewCell) {
        isRemovingAsset = true
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            cell.alpha = 0
            cell.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        } completion: { _ in
            if let index = self.assets.firstIndex(of: asset) {
                self.collectionView.performBatchUpdates {
                    self.assets.remove(at: index)
                    self.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
                } completion: { _ in
                    self.assets = self.selectedAssets
                    self.collectionView.reloadData()
                    self.isRemovingAsset = false
                }
            } else {
                self.assets = self.selectedAssets
                self.collectionView.reloadData()
                self.isRemovingAsset = false
            }
        }
    }
    
    private func addedMediaWillDisplay(_ cell: UICollectionViewCell) {
        cell.alpha = 0
        cell.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.3, delay: 0.2, options: .curveEaseOut) {
            cell.transform = .identity
            cell.alpha = 1
        } completion: { _ in
            self.isAddingAsset = false
        }
    }
    
}
