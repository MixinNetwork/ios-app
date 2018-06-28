import UIKit
import WebKit
import Photos
import FLAnimatedImage

class AssetSendViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var photoImageView: FLAnimatedImageView!
    @IBOutlet weak var videoView: GalleryVideoView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var sendButton: StateResponsiveButton!
    @IBOutlet weak var dismissButton: BouncingButton!

    private weak var dataSource: ConversationDataSource?

    private let rateKey = "rate"

    private var image: UIImage?
    private var asset: PHAsset?
    private var animateURL: URL?
    private var videoAsset: AVAsset?
    private var isObservingRate = false
    private var seekToZero = false

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let image = self.image {
            photoImageView.image = image
        } else if let asset = self.videoAsset {
            DispatchQueue.global().async { [weak self] in
                let thumbnail = UIImage(withFirstFrameOfVideoAtAsset: asset)
                DispatchQueue.main.async {
                    self?.loadAsset(asset: asset, thumbnail: thumbnail)
                }
            }
        } else if let asset = self.asset {
            if asset.mediaType == .video {
                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { [weak self](avasset, _, _) in
                    guard let avasset = avasset else {
                        return
                    }
                    let thumbnail = UIImage(withFirstFrameOfVideoAtAsset: avasset)
                    DispatchQueue.main.async {
                        self?.loadAsset(asset: avasset, thumbnail: thumbnail)
                    }
                }
            } else {
                if let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename.lowercased(), let startIndex = filename.index(of: "."), startIndex < filename.endIndex {
                    let fileExtension = String(filename[startIndex..<filename.endIndex])
                    if fileExtension.hasSuffix(".webp") || fileExtension.hasSuffix(".gif") {
                        PHImageManager.default().requestImageData(for: asset, options: nil, resultHandler: { [weak self](data, _, _, _) in
                            let tempUrl = URL.createTempUrl(fileExtension: fileExtension)
                            do {
                                try data?.write(to: tempUrl)
                                self?.animateURL = tempUrl
                                self?.photoImageView.sd_setImage(with: tempUrl)
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
    }

    private func requestAssetImage(asset: PHAsset) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.version = .current
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestOptions, resultHandler: { [weak self](image, _) in
            self?.photoImageView.image = image
        })
    }

    @IBAction func playAction(_ sender: Any) {
        if seekToZero {
            seekToZero = false
            videoView.seek(to: kCMTimeZero)
        }
        videoView.play()
    }

    private func loadAsset(asset: AVAsset, thumbnail: UIImage?) {
        self.sendButton.activityIndicator.activityIndicatorViewStyle = .white
        self.videoAsset = asset
        self.playButton.isHidden = false
        self.videoView.isHidden = false
        self.photoImageView.isHidden = true
        videoView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pauseAction)))
        videoView.loadVideo(asset: asset, thumbnail: thumbnail)
        videoView.player.addObserver(self, forKeyPath: rateKey, options: [.initial, .new], context: nil)
        isObservingRate = true
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: .UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    @objc func pauseAction() {
        videoView.pause()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "rate" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        let isPlayingVideo = videoView.isPlaying()
        playButton.isHidden = isPlayingVideo
        sendButton.isHidden = isPlayingVideo
        dismissButton.isHidden = isPlayingVideo
        UIApplication.shared.isIdleTimerDisabled = isPlayingVideo
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if isObservingRate {
            videoView.player.removeObserver(self, forKeyPath: rateKey)
            isObservingRate = false
        }
    }

    @IBAction func sendAction(_ sender: Any) {
        guard !sendButton.isBusy else {
            return
        }
        sendButton.isBusy = true
        if let asset = self.videoAsset {
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else {
                sendButton.isBusy = false
                alert(Localized.CHAT_SEND_VIDEO_FAILED)
                return
            }
            let filename = UUID().uuidString.lowercased()
            let outputURL = MixinFile.url(ofChatDirectory: .videos, filename: filename + ExtensionName.mp4.withDot)
            exportSession.outputFileType = .mp4
            exportSession.outputURL = outputURL
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.exportAsynchronously(completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    guard exportSession.status == .completed else {
                        self?.sendButton.isBusy = false
                        self?.alert(Localized.CHAT_SEND_VIDEO_FAILED)
                        return
                    }
                    if let dataSource = self?.dataSource {
                        dataSource.sendMessage(type: .SIGNAL_VIDEO, value: (outputURL, asset))
                        self?.navigationController?.popViewController(animated: true)
                    } else {
                        self?.navigationController?.pushViewController(SendToViewController.instance(videoUrl: outputURL), animated: true)
                    }

                }
            })
        } else if let image = photoImageView.image, let dataSource = dataSource {
            var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue, conversationId: dataSource.conversationId, userId: AccountAPI.shared.accountUserId)
            message.mediaStatus = MediaStatus.PENDING.rawValue

            DispatchQueue.global().async { [weak self] in
                if let assetUrl = self?.animateURL {
                    guard FileManager.default.fileSize(assetUrl.path) > 0 else {
                        DispatchQueue.main.async {
                            self?.sendButton.isBusy = false
                            self?.alert(Localized.CHAT_SEND_PHOTO_FAILED)
                        }
                        return
                    }
                    let fileExtension = assetUrl.pathExtension.lowercased()
                    let filename = "\(message.messageId).\(fileExtension)"
                    let targetUrl = MixinFile.url(ofChatDirectory: .photos, filename: filename)
                    do {
                        try FileManager.default.copyItem(at: assetUrl, to: targetUrl)

                        message.thumbImage = image.getBlurThumbnail().toBase64()
                        message.mediaSize = FileManager.default.fileSize(targetUrl.path)
                        message.mediaWidth = Int(image.size.width)
                        message.mediaHeight = Int(image.size.height)
                        message.mediaMimeType = FileManager.default.mimeType(ext: fileExtension)
                        message.mediaUrl = filename
                    } catch {
                        DispatchQueue.main.async {
                            self?.sendButton.isBusy = false
                            self?.alert(Localized.CHAT_SEND_PHOTO_FAILED)
                        }
                        return
                    }
                } else {
                    let filename = "\(message.messageId).\(ExtensionName.jpeg)"
                    let targetUrl = MixinFile.url(ofChatDirectory: .photos, filename: filename)
                    let targetPhoto = image.scaleForUpload()
                    if targetPhoto.saveToFile(path: targetUrl), FileManager.default.fileSize(targetUrl.path) > 0 {
                        message.thumbImage = targetPhoto.getBlurThumbnail().toBase64()
                        message.mediaSize = FileManager.default.fileSize(targetUrl.path)
                        message.mediaWidth = Int(targetPhoto.size.width)
                        message.mediaHeight = Int(targetPhoto.size.height)
                        message.mediaMimeType = "image/jpeg"
                        message.mediaUrl = filename
                    } else {
                        DispatchQueue.main.async {
                            self?.sendButton.isBusy = false
                            self?.alert(Localized.CHAT_SEND_PHOTO_FAILED)
                        }
                        return
                    }
                }
                SendMessageService.shared.sendMessage(message: message, ownerUser: dataSource.ownerUser, isGroupMessage: dataSource.category == .group)
                DispatchQueue.main.async {
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    class func instance(image: UIImage? = nil, asset: PHAsset? = nil, videoAsset: AVAsset? = nil, dataSource: ConversationDataSource?) -> UIViewController {
       let vc = Storyboard.chat.instantiateViewController(withIdentifier: "send_asset") as! AssetSendViewController
        vc.image = image
        vc.asset = asset
        vc.videoAsset = videoAsset
        vc.dataSource = dataSource
        return vc
    }

}

extension AssetSendViewController {

    @objc func applicationWillResignActive(_ sender: Notification) {
        videoView.pause()
    }

    @objc func playerItemDidReachEnd(_ notification: Notification) {
        seekToZero = true
    }
}
