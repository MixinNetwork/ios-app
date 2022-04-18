import CoreServices
import UIKit
import Photos
import SDWebImage
import MixinServices

class StickerAddViewController: UIViewController {
    
    enum Source {
        case message(MessageItem)
        case asset(PHAsset)
        case image(UIImage)
    }
    
    @IBOutlet weak var previewImageView: SDAnimatedImageView!
    
    private let minStickerLength: CGFloat = 128
    private let maxStickerLength: CGFloat = 1024
    private let minDataCount = bytesPerKiloByte
    private let maxDataCount = bytesPerMegaByte
    
    private var source: Source?
    private var uploadPNGData = false
    
    class func instance(source: Source) -> UIViewController {
        let vc = R.storyboard.chat.sticker_add()!
        vc.source = source
        return ContainerViewController.instance(viewController: vc, title: Localized.STICKER_ADD_TITLE)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch source {
        case .message(let item):
            uploadPNGData = item.mediaMimeType == "image/png"
            let updateRightButton: SDExternalCompletionBlock = { [weak self] (image, error, _, _) in
                self?.container?.rightButton.isEnabled = image != nil
            }
            if let assetUrl = item.assetUrl {
                let context = [SDWebImageContextOption.animatedImageClass: SDAnimatedImage.self]
                previewImageView.sd_setImage(with: URL(string: assetUrl),
                                             placeholderImage: nil,
                                             context: context,
                                             progress: nil,
                                             completed: updateRightButton)
            } else if let mediaUrl = item.mediaUrl {
                let url = AttachmentContainer.url(for: .photos, filename: mediaUrl)
                previewImageView.sd_setImage(with: url,
                                             placeholderImage: nil,
                                             context: localImageContext,
                                             progress: nil,
                                             completed: updateRightButton)
            } else {
                // container's right button will keep disabled if no image is loaded
            }
        case .asset(let asset):
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            if asset.playbackStyle == .imageAnimated {
                uploadPNGData = false
                manager.requestImageDataAndOrientation(for: asset, options: options) { [weak self] (data, _, _, _) in
                    guard let self = self, let data = data, let image = SDAnimatedImage(data: data) else {
                        return
                    }
                    self.previewImageView.image = image
                    self.container?.rightButton.isEnabled = true
                }
            } else {
                if let uti = asset.uniformTypeIdentifier {
                    uploadPNGData = UTTypeConformsTo(uti, kUTTypePNG)
                } else {
                    uploadPNGData = false
                }
                manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { [weak self] (image, _) in
                    guard let self = self, let image = image else {
                        return
                    }
                    self.previewImageView.image = image
                    self.container?.rightButton.isEnabled = true
                }
            }
        case .image(let image):
            uploadPNGData = false
            previewImageView.image = image
            container?.rightButton.isEnabled = true
        case .none:
            assertionFailure("No image is loaded")
            break
        }
    }
    
}

extension StickerAddViewController: ContainerViewControllerDelegate {
    
    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.setTitleColor(.systemTint, for: .normal)
        rightButton.isEnabled = false
    }
    
    func barRightButtonTappedAction() {
        guard let rightButton = container?.rightButton, !rightButton.isBusy else {
            return
        }
        guard let image = previewImageView.image else {
            showFailureAlert()
            assertionFailure("This is not expected to happen since right button should be disabled before any image is presented")
            return
        }
        rightButton.isBusy = true
        if let image = previewImageView.image as? SDAnimatedImage, image.animatedImageFrameCount > 1, let data = image.animatedImageData {
            let isSizeValid = min(image.size.width, image.size.height) >= minStickerLength
                && max(image.size.width, image.size.height) <= maxStickerLength
            if isSizeValid {
                performAddition(data: data)
            } else {
                showMalformedAlert()
            }
        } else {
            let ratio = image.size.width / image.size.height
            let isRatioValid = ratio >= minStickerLength / maxStickerLength
                && ratio <= maxStickerLength / minStickerLength
            if isRatioValid {
                addStaticImage(image: image)
            } else {
                showMalformedAlert()
            }
        }
    }
    
    func textBarRightButton() -> String? {
        return Localized.ACTION_SAVE
    }
    
}

extension StickerAddViewController {
    
    private func showMalformedAlert() {
        container?.rightButton.isBusy = false
        let title = R.string.localizable.sticker_add_requirements("\(minDataCount / bytesPerKiloByte)", "\(maxDataCount / bytesPerKiloByte)", "\(Int(minStickerLength))", "\(Int(maxStickerLength))")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_ok(), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func showFailureAlert() {
        container?.rightButton.isBusy = false
        showAutoHiddenHud(style: .error, text: R.string.localizable.error_operation_failed())
    }
    
    private func addStaticImage(image: UIImage) {
        let scalingSize: CGSize?
        if min(image.size.width, image.size.height) < minStickerLength {
            let canvasSize = CGSize(width: minStickerLength, height: minStickerLength)
            scalingSize = image.size.sizeThatFills(canvasSize)
        } else if max(image.size.width, image.size.height) > maxStickerLength {
            let canvasSize = CGSize(width: maxStickerLength, height: maxStickerLength)
            scalingSize = image.size.sizeThatFits(canvasSize)
        } else {
            scalingSize = nil
        }
        let uploadPNGData = self.uploadPNGData
        DispatchQueue.global().async { [weak self] in
            let scaled: UIImage?
            if let size = scalingSize {
                scaled = image.imageByScaling(to: size)
            } else {
                scaled = image
            }
            let data: Data?
            if uploadPNGData {
                data = scaled?.pngData()
            } else {
                data = scaled?.jpegData(compressionQuality: JPEGCompressionQuality.medium)
            }
            DispatchQueue.main.async {
                if let data = data {
                    self?.performAddition(data: data)
                } else {
                    self?.showFailureAlert()
                }
            }
        }
    }
    
    private func performAddition(data: Data) {
        guard data.count <= maxDataCount && data.count >= minDataCount else {
            showMalformedAlert()
            return
        }
        let base64 = data.base64EncodedString()
        StickerAPI.addSticker(stickerBase64: base64, completion: { [weak self] (result) in
            switch result {
            case let .success(sticker):
                SDImageCache.persistentSticker.storeImageData(toDisk: data, forKey: sticker.assetUrl)
                DispatchQueue.global().async { [weak self] in
                    StickerDAO.shared.insertOrUpdateFavoriteSticker(sticker: sticker)
                    DispatchQueue.main.async {
                        showAutoHiddenHud(style: .notification, text: Localized.TOAST_ADDED)
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            case let .failure(error):
                self?.container?.rightButton.isBusy = false
                switch error {
                case let .invalidRequestData(field):
                    if field == "width" {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.error_invalid_width())
                    } else if field == "height" {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.error_invalid_height())
                    } else {
                        fallthrough
                    }
                default:
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        })
    }
    
}
