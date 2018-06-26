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
            stickerImageView.sd_setImage(with: MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl))
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
                        if let album = AlbumDAO.shared.getSelfAlbum() {
                            StickerAlbumDAO.shared.inserOrUpdate(albumId: album.albumId, stickers: [sticker])
                        }
                        StickerDAO.shared.insertOrUpdateStickers(stickers: [sticker])

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
            if let assetUrl = self?.animateURL {
                guard FileManager.default.validateFileSize(assetUrl.path) else {
                    failedBlock()
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
                if targetPhoto.saveToFile(path: targetUrl), let stickerBase64 = targetPhoto.base64, FileManager.default.validateFileSize(targetUrl.path) {
                    addBloack(stickerBase64)
                } else {
                    failedBlock()
                }
            }
        }
    }

    func textBarRightButton() -> String? {
        return Localized.ACTION_SAVE
    }

}

private extension FileManager {

    func validateFileSize(_ path: String) -> Bool {
        let size = fileSize(path)
        return size > 1024 && size < 1024 * 1024
    }

}

