import CoreServices
import UIKit
import SDWebImage
import MixinServices

final class StickerAddViewController: UIViewController {
    
    enum Source {
        case message(MessageItem)
        case image(UIImage)
    }
    
    @IBOutlet weak var previewImageView: SDAnimatedImageView!
    
    private let source: Source
    private let minStickerLength: CGFloat = 128
    private let maxStickerLength: CGFloat = 1024
    private let minDataCount = bytesPerKiloByte
    private let maxDataCount = bytesPerMegaByte
    
    private var uploadPNGData = false
    
    private weak var rightBarButton: BusyButton?
    
    init(source: Source) {
        self.source = source
        let nib = R.nib.stickerAddView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.add_sticker()
        navigationItem.rightBarButtonItem = .busyButton(
            title: R.string.localizable.save(),
            target: self,
            action: #selector(save(_:))
        )
        rightBarButton = navigationItem.rightBarButtonItem?.customView as? BusyButton
        switch source {
        case .message(let item):
            uploadPNGData = item.mediaMimeType == "image/png"
            let updateRightButton: SDExternalCompletionBlock = { [weak self] (image, error, _, _) in
                self?.rightBarButton?.isEnabled = image != nil
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
        case .image(let image):
            uploadPNGData = false
            previewImageView.image = image
            rightBarButton?.isEnabled = true
        }
    }
    
    @objc private func save(_ sender: BusyButton) {
        guard let rightButton = rightBarButton, !rightButton.isBusy else {
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
    
}

extension StickerAddViewController {
    
    private func showMalformedAlert() {
        rightBarButton?.isBusy = false
        let title = R.string.localizable.sticker_add_requirements("\(minDataCount / bytesPerKiloByte)", "\(maxDataCount / bytesPerKiloByte)", "\(Int(minStickerLength))", "\(Int(maxStickerLength))")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func showFailureAlert() {
        rightBarButton?.isBusy = false
        showAutoHiddenHud(style: .error, text: R.string.localizable.operation_failed())
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
        let image = data.base64RawURLEncodedString()
        StickerAPI.addSticker(base64EncodedImage: image) { [weak self] (result) in
            switch result {
            case let .success(sticker):
                SDImageCache.persistentSticker.storeImageData(toDisk: data, forKey: sticker.assetUrl)
                DispatchQueue.global().async { [weak self] in
                    StickerDAO.shared.insertOrUpdateFavoriteSticker(sticker: sticker)
                    DispatchQueue.main.async {
                        showAutoHiddenHud(style: .notification, text: R.string.localizable.added())
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            case let .failure(error):
                self?.rightBarButton?.isBusy = false
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
}
