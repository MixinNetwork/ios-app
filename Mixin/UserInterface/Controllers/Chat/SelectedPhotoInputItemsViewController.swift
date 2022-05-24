import UIKit
import Photos

protocol SelectedPhotoInputItemsViewControllerDelegate: AnyObject {
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didSend assets: [PHAsset])
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didDeselect asset: PHAsset)
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didSelectAssetAt index: Int)
    func selectedPhotoInputItemsViewController(_ controller: SelectedPhotoInputItemsViewController, didCancelSend assets: [PHAsset])
}

final class SelectedPhotoInputItemsViewController: UIViewController {
    
    let viewHeight: CGFloat = 224
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var sendButton: UIButton!
    
    weak var delegate: SelectedPhotoInputItemsViewControllerDelegate?
    
    private var cellSizeCache = [String: CGSize]()
    private var assets = [PHAsset]() {
        didSet {
            sendButton.setTitle(R.string.localizable.send_count(assets.count), for: .normal)
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        delegate?.selectedPhotoInputItemsViewController(self, didCancelSend: assets)
    }
    
    @IBAction func sendAction(_ sender: Any) {
        delegate?.selectedPhotoInputItemsViewController(self, didSend: assets)
    }
    
}

extension SelectedPhotoInputItemsViewController {
    
    func add(_ asset: PHAsset) {
        guard !assets.contains(asset) else {
            return
        }
        assets.append(asset)
        let index = IndexPath(item: assets.count - 1, section: 0)
        collectionView.insertItems(at: [index])
        collectionView.scrollToItem(at: index, at: .centeredHorizontally, animated: true)
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

extension SelectedPhotoInputItemsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.selected_media, for: indexPath)!
        if indexPath.item < assets.count {
            let asset = assets[indexPath.item]
            cell.load(asset: asset, size: cellSizeForItemAt(indexPath.item))
            cell.deselectAsset = { [weak self] in
                guard let self = self else {
                    return
                }
                self.remove(asset)
                self.delegate?.selectedPhotoInputItemsViewController(self, didDeselect: asset)
            }
        }
        return cell
    }
    
}

extension SelectedPhotoInputItemsViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        cellSizeForItemAt(indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.selectedPhotoInputItemsViewController(self, didSelectAssetAt: indexPath.item)
    }
    
}

extension SelectedPhotoInputItemsViewController {
    
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
                width = ceil(height / 3 * 4)
            } else if ratio < 1 {
                width = ceil(height / 4 * 3)
            } else {
                width = height
            }
            let size = CGSize(width: width, height: height)
            cellSizeCache[asset.localIdentifier] = size
            return size
        }
    }
    
}
