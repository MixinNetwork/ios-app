import UIKit
import Photos
import MobileCoreServices

class PickerViewController: UICollectionViewController, MixinNavigationAnimating {

    private var imageRequestOptions: PHImageRequestOptions = {
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
    private var collection: PHAssetCollection?
    private var assets: PHFetchResult<PHAsset>!
    private var isFilterCustomSticker = false
    
    private lazy var itemSize: CGSize = {
        let rowCount = floor(UIScreen.main.bounds.size.width / 90)
        let itemWidth = (UIScreen.main.bounds.size.width - rowCount * 1) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }()
    private var scrollToBottom = false

    override func viewDidLoad() {
        super.viewDidLoad()
        container?.rightButton.isEnabled = true
        if let collection = collection {
            let options = PHFetchOptions()
            if isFilterCustomSticker {
                options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            }
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            assets = PHAsset.fetchAssets(in: collection, options: options)
        } else {
            assets = PHFetchResult<PHAsset>()
        }
        collectionView?.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !scrollToBottom && assets.count > 0 {
            scrollToBottom = true
            collectionView?.scrollToItem(at: IndexPath(row: assets.count - 1, section: 0), at: .bottom, animated: false)
        }
    }
    class func instance(collection: PHAssetCollection? = nil, isFilterCustomSticker: Bool) -> UIViewController {
        let vc = Storyboard.photo.instantiateViewController(withIdentifier: "picker") as! PickerViewController
        if let collection = collection {
            vc.collection = collection
        } else {
            vc.collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject
        }
        vc.isFilterCustomSticker = isFilterCustomSticker
        return vc
    }

}

extension PickerViewController: ContainerViewControllerDelegate {

    func barLeftButtonTappedAction() {
        navigationController?.popViewController(animated: true)
    }

    func textBarRightButton() -> String? {
        return Localized.DIALOG_BUTTON_CANCEL
    }

    func barRightButtonTappedAction() {
        dismiss(animated: true, completion: nil)
    }
    
}

extension PickerViewController: UICollectionViewDelegateFlowLayout {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return itemSize
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell_identifier_picker", for: indexPath) as! PickerCell
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
            PHImageManager.default().requestImageData(for: asset, options: utiCheckingImageRequestOptions, resultHandler: { (_, uti, _, _) in
                if let uti = uti, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
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

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        navigationController?.dismiss(animated: true, completion: nil)
        (navigationController as? PhotoAssetPickerNavigationController)?.pickerDelegate?.pickerController(self, didFinishPickingMediaWithAsset: assets[indexPath.row])
    }
    
}

class PickerCell: UICollectionViewCell {

    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var fileTypeView: UIView!
    @IBOutlet weak var gifLabel: UILabel!
    @IBOutlet weak var videoImageView: UIImageView!
    @IBOutlet weak var durationLabel: UILabel!

    var requestId: PHImageRequestID = -1
    var localIdentifier: String!

    override func prepareForReuse() {
        super.prepareForReuse()
        PHCachingImageManager.default().cancelImageRequest(requestId)
    }
}
