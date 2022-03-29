import UIKit
import Photos

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
    
    private var cellSizeCache = [String: CGSize]()
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
        assets.append(asset)
        collectionView.insertItems(at: [IndexPath(item: assets.count - 1, section: 0)])
        collectionView.scrollToItem(at: IndexPath(item: assets.count - 1, section: 0),
                                    at: .centeredHorizontally,
                                    animated: true)
    }
    
    func remove(_ asset: PHAsset) {
        guard let index = assets.firstIndex(of: asset) else {
            return
        }
        assets.remove(at: index)
        cellSizeCache.removeValue(forKey: asset.localIdentifier)
        collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
    }
    
    func removeAllAssets() {
        cellSizeCache.removeAll()
        assets.removeAll()
        collectionView.reloadData()
    }
    
    func updateAssets(_ selectedAssets: [PHAsset]) {
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
                self.remove(asset)
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
    
}
