import UIKit
import Photos

protocol PickerViewControllerDelegate: class {

    func pickerController(_ picker: PickerViewController, didFinishPickingMediaWithAsset asset: PHAsset)
}

class PickerViewController: UICollectionViewController, MixinNavigationAnimating {

    private var type: PHAssetCollectionType!
    private var subtype: PHAssetCollectionSubtype!
    private var imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        return options
    }()
    private lazy var defaultCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
    private lazy var currentCollection = defaultCollection.firstObject

    private var assets = PHFetchResult<PHAsset>()
    private lazy var itemSize: CGSize = {
        let rowCount = floor(UIScreen.main.bounds.size.width / 90)
        let itemWidth = (UIScreen.main.bounds.size.width - rowCount * 1) / rowCount
        return CGSize(width: itemWidth, height: itemWidth)
    }()
    private var scrollToBottom = false

    weak var delegate: PickerViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        container?.rightButton.isEnabled = true
        reloadAssets()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !scrollToBottom && assets.count > 0 {
            scrollToBottom = true
            collectionView?.scrollToItem(at: IndexPath(row: assets.count - 1, section: 0), at: .bottom, animated: false)
        }
    }

    private func reloadAssets() {
        defer {
            collectionView?.reloadData()
        }
        guard let collection = currentCollection else {
            self.assets = PHFetchResult<PHAsset>()
            return
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        self.assets = PHAsset.fetchAssets(in: collection, options: options)
    }

    class func instance() -> PickerViewController {
        let vc = Storyboard.photo.instantiateViewController(withIdentifier: "picker") as! PickerViewController
        vc.type = .smartAlbum
        vc.subtype = .smartAlbumUserLibrary
        return vc
    }

}

extension PickerViewController: ContainerViewControllerDelegate {

    func barLeftButtonTappedAction() {
        let vc = Storyboard.photo.instantiateViewController(withIdentifier: "album") as! AlbumViewController
        vc.delegate = self
        navigationController?.pushViewController(ContainerViewController.instance(viewController: vc, title: Localized.IMAGE_PICKER_TITLE_ALBUMS), animated: true)
    }

    func textBarRightButton() -> String? {
        return Localized.DIALOG_BUTTON_CANCEL
    }

    func barRightButtonTappedAction() {
        navigationController?.popViewController(animated: true)
    }
}

extension PickerViewController: AlbumViewControllerDelegate {

    func albumController(_ albumController: AlbumViewController, didSelectRowAtCollection collection: PHAssetCollection, title: String) {
        self.currentCollection = collection
        self.container?.titleLabel.text = title
        self.scrollToBottom = false
        self.reloadAssets()
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
            cell.videoTypeView.isHidden = false
            cell.durationLabel.text = mmssComponentsFormatter.string(from: asset.duration)
        } else {
            cell.videoTypeView.isHidden = true
        }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        navigationController?.popViewController(animated: true)
        delegate?.pickerController(self, didFinishPickingMediaWithAsset: assets[indexPath.row])
    }
}

class PickerCell: UICollectionViewCell {

    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var videoTypeView: UIView!
    @IBOutlet weak var durationLabel: UILabel!

    var requestId: PHImageRequestID = -1
    var localIdentifier: String!

    override func prepareForReuse() {
        super.prepareForReuse()
        PHCachingImageManager.default().cancelImageRequest(requestId)
    }
}
