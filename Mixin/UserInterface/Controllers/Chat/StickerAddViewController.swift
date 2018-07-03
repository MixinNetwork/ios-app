import UIKit
import FLAnimatedImage
import Photos
import SDWebImage

class StickerAddViewController: UIViewController {

    @IBOutlet weak var stickerImageView: FLAnimatedImageView!

    private var message: MessageItem?
    private var asset: PHAsset?
    private var animateURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let assetUrl = message?.assetUrl {
            stickerImageView.sd_setImage(with: URL(string: assetUrl))
        } else if let mediaUrl = message?.mediaUrl {
            let url = MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
            if mediaUrl.hasSuffix(".webp") || mediaUrl.hasSuffix(".gif") {
                animateURL = url
            }
            stickerImageView.sd_setImage(with: url)
        } else if let asset = self.asset {
            if let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename.lowercased(), let startIndex = filename.index(of: "."), startIndex < filename.endIndex {
                let fileExtension = String(filename[startIndex..<filename.endIndex])
                if fileExtension.hasSuffix(".webp") || fileExtension.hasSuffix(".gif") {
                    PHImageManager.default().requestImageData(for: asset, options: nil, resultHandler: { [weak self](data, _, _, _) in
                        let filename = "\(UUID().uuidString.lowercased())\(fileExtension)"
                        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
                        do {
                            try data?.write(to: tempUrl)
                            self?.animateURL = tempUrl
                            self?.stickerImageView.sd_setImage(with: tempUrl)
                        } catch {
                            self?.requestAssetImage(asset: asset)
                        }
                    })
                    return
                }
            }
            requestAssetImage(asset: asset)
        }
    }

    private func requestAssetImage(asset: PHAsset) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.version = .current
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestOptions, resultHandler: { [weak self](image, _) in
            self?.stickerImageView.image = image
        })
    }

    class func instance(message: MessageItem) -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "sticker_add") as! StickerAddViewController
        vc.message = message
        return ContainerViewController.instance(viewController: vc, title: Localized.STICKER_ADD_TITLE)
    }

    class func instance(asset: PHAsset) -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "sticker_add") as! StickerAddViewController
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: Localized.STICKER_ADD_TITLE)
    }

}

extension StickerAddViewController: ContainerViewControllerDelegate {

    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.isEnabled = true
        rightButton.setTitleColor(.systemTint, for: .normal)
    }

    func barRightButtonTappedAction() {
        guard let rightButton = container?.rightButton, !rightButton.isBusy, let image = stickerImageView.image else {
            return
        }
        rightButton.isBusy = true

        let alertBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.container?.rightButton.isBusy = false
                self?.alert(Localized.STICKER_ADD_REQUIRED)
            }
        }

        let failedBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.container?.rightButton.isBusy = false
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.STICKER_ADD_FAILED)
            }
        }

        let addBloack = { (stickerBase64: String) in
            StickerAPI.shared.addSticker(stickerBase64: stickerBase64, completion: { [weak self](result) in
                switch result {
                case let .success(sticker):
                    SDWebImageManager.shared().imageCache?.storeImageData(toDisk: Data(base64Encoded: stickerBase64), forKey: sticker.assetUrl)
                    DispatchQueue.global().async {
                        StickerDAO.shared.insertOrUpdateFavoriteSticker(sticker: sticker)
                        DispatchQueue.main.async {
                            NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.TOAST_ADDED)
                            self?.navigationController?.popViewController(animated: true)
                        }
                    }
                case .failure:
                    failedBlock()
                }
            })
        }

        DispatchQueue.global().async { [weak self] in
            if let assetUrl = self?.animateURL, !FileManager.default.isStillImage(assetUrl.path) {
                guard FileManager.default.validateSticker(assetUrl.path) else {
                    alertBlock()
                    return
                }
                let fileExtension = assetUrl.pathExtension.lowercased()
                let filename = "\(UUID().uuidString.lowercased()).\(fileExtension)"
                let targetUrl = MixinFile.url(ofChatDirectory: .photos, filename: filename)
                do {
                    try FileManager.default.copyItem(at: assetUrl, to: targetUrl)
                    if let stickerBase64 = FileManager.default.contents(atPath: targetUrl.path)?.base64EncodedString() {
                        addBloack(stickerBase64)
                    } else {
                        failedBlock()
                    }
                } catch {
                    failedBlock()
                }
            } else {
                let filename = "\(UUID().uuidString.lowercased()).\(ExtensionName.jpeg)"
                let targetUrl = MixinFile.url(ofChatDirectory: .photos, filename: filename)
                let targetPhoto = image.scaledToSticker()
                if targetPhoto.saveToFile(path: targetUrl), let stickerBase64 = targetPhoto.base64, FileManager.default.validateSticker(targetUrl.path) {
                    addBloack(stickerBase64)
                } else {
                    alertBlock()
                }
            }
        }
    }

    func textBarRightButton() -> String? {
        return Localized.ACTION_SAVE
    }

}

private extension FileManager {


    func validateSticker(_ path: String) -> Bool {
        let fSize = fileSize(path)
        guard fSize > 1024 && fSize < 1024 * 800 else {
            return false
        }
        let size = imageSize(path)
        return min(size.width, size.height) >= 64.0 && max(size.width, size.height) <= 512
    }

}

