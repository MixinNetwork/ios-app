import UIKit
import Photos

protocol MediasPreviewWindowDelegate: AnyObject {
    func mediasPreviewWindow(_ window: MediasPreviewWindow, didSendItems assets: [PHAsset])
    func mediasPreviewWindow(_ window: MediasPreviewWindow, didSendFiles assets: [PHAsset])
    func mediasPreviewWindow(_ window: MediasPreviewWindow, willDismiss assets: [PHAsset])
}

final class MediasPreviewWindow: BottomSheetView {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var sendPhotoButton: RoundedButton!
    @IBOutlet weak var sendFileButton: UIButton!
    @IBOutlet weak var flowLayout: SnappingFlowLayout!
    
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: MediasPreviewWindowDelegate?
    
    private var assets = [PHAsset]()
    private var selectedAssets = [PHAsset]()
    private var lastWidth: CGFloat = 0
    private var isSending = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        sendFileButton.setTitleColor(.theme, for: .normal)
        sendFileButton.setTitleColor(R.color.button_background_disabled(), for: .disabled)
        collectionView.decelerationRate = .fast
        collectionView.isPagingEnabled = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsMultipleSelection = true
        collectionView.register(R.nib.mediaPreviewCell)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        if lastWidth != width {
            lastWidth = width
            let inset = (width - collectionViewHeightConstraint.constant) / 2
            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        }
    }
    
    override func dismissPopupControllerAnimated() {
        if !isSending {
            delegate?.mediasPreviewWindow(self, willDismiss: selectedAssets)
        }
        super.dismissPopupControllerAnimated()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        isSending = false
        dismissPopupControllerAnimated()
    }
    
    @IBAction func sendPhotosAction(_ sender: Any) {
        isSending = true
        dismissPopupControllerAnimated()
        delegate?.mediasPreviewWindow(self, didSendItems: selectedAssets)
    }
    
    @IBAction func sendAsFilesAction(_ sender: Any) {
        isSending = true
        dismissPopupControllerAnimated()
        delegate?.mediasPreviewWindow(self, didSendFiles: selectedAssets)
    }
    
    func load(assets: [PHAsset], initIndex: Int) {
        self.assets = assets
        selectedAssets = assets
        updateUI()
        collectionView.reloadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.collectionView.scrollToItem(at: IndexPath(item: initIndex, section: 0), at: .centeredHorizontally, animated: false)
        }
    }
    
    class func instance() -> MediasPreviewWindow {
        R.nib.mediaPreviewWindow(owner: nil)!
    }
    
}

extension MediasPreviewWindow: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.media_preview, for: indexPath)!
        if indexPath.item < assets.count {
            let asset = assets[indexPath.item]
            cell.load(asset: asset)
            cell.updateSelectedStatus(isSelected: selectedAssets.contains(asset))
        }
        return cell
    }
 
}

extension MediasPreviewWindow: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        MediaPreviewCell.cellSize
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let cell = collectionView.cellForItem(at: indexPath) as? MediaPreviewCell else {
            return
        }
        let asset = assets[indexPath.item]
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
            cell.updateSelectedStatus(isSelected: false)
        } else {
            selectedAssets.append(asset)
            cell.updateSelectedStatus(isSelected: true)
        }
        updateUI()
    }
    
}

extension MediasPreviewWindow {
    
    private func updateUI() {
        let title: String
        let sendPhotoButtonTitle: String
        let sendFileButtonTitle: String
        let isEnabled: Bool
        if selectedAssets.count == 0 {
            title = R.string.localizable.chat_media_preview_select_no_item()
            sendPhotoButtonTitle = R.string.localizable.chat_media_preview_send_items(0)
            sendFileButtonTitle = R.string.localizable.chat_media_preview_send_files()
            isEnabled = false
        } else if selectedAssets.count == 1 {
            switch selectedAssets[0].mediaType {
            case .image:
                title = R.string.localizable.chat_media_preview_select_photo()
                sendPhotoButtonTitle = R.string.localizable.chat_media_preview_send_photo()
            case .video:
                title = R.string.localizable.chat_media_preview_select_video()
                sendPhotoButtonTitle = R.string.localizable.chat_media_preview_send_video()
            default:
                title = R.string.localizable.chat_media_preview_select_item()
                sendPhotoButtonTitle = R.string.localizable.chat_media_preview_send_item()
            }
            sendFileButtonTitle = R.string.localizable.chat_media_preview_send_file()
            isEnabled = true
        } else {
            let count = selectedAssets.count
            let isAllImages = selectedAssets.allSatisfy { $0.mediaType == .image }
            let isAllVideos = selectedAssets.allSatisfy { $0.mediaType == .video }
            if isAllImages {
                title = R.string.localizable.chat_media_preview_select_photos(count)
                sendPhotoButtonTitle = R.string.localizable.chat_media_preview_send_photos(count)
            } else if isAllVideos {
                title = R.string.localizable.chat_media_preview_select_videos(count)
                sendPhotoButtonTitle = R.string.localizable.chat_media_preview_send_videos(count)
            } else {
                title = R.string.localizable.chat_media_preview_select_items(count)
                sendPhotoButtonTitle = R.string.localizable.chat_media_preview_send_items(count)
            }
            sendFileButtonTitle = R.string.localizable.chat_media_preview_send_files()
            isEnabled = true
        }
        label.text = title
        sendPhotoButton.setTitle(sendPhotoButtonTitle, for: .normal)
        sendFileButton.setTitle(sendFileButtonTitle, for: .normal)
        sendPhotoButton.isEnabled = isEnabled
        sendFileButton.isEnabled = isEnabled
    }
    
}
