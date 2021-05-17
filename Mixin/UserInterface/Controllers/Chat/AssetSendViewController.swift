import UIKit
import WebKit
import Photos
import YYImage
import MixinServices

class AssetSendViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var photoImageView: YYAnimatedImageView!
    @IBOutlet weak var videoView: AssetSendVideoView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var sendButton: StateResponsiveButton!
    @IBOutlet weak var dismissButton: BouncingButton!
    
    var detectsQrCode = false
    var showSaveButton = false
    
    private weak var composer: ConversationMessageComposer?
    
    private let rateKey = "rate"

    private var image: UIImage?
    private var asset: PHAsset?
    private var animateURL: URL?
    private var videoAsset: AVAsset?
    private var isObservingRate = false
    private var seekToZero = false
    
    private lazy var notificationController = NotificationController(delegate: self)

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        saveButton.isHidden = !showSaveButton
        if let image = self.image {
            photoImageView.image = image
            if detectsQrCode {
                DispatchQueue.global().async { [weak self] in
                    self?.detectQrCode(image: image)
                }
            }
        } else if let asset = self.videoAsset {
            DispatchQueue.global().async { [weak self] in
                let thumbnail = UIImage(withFirstFrameOf: asset)
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
                    let thumbnail = UIImage(withFirstFrameOf: avasset)
                    DispatchQueue.main.async {
                        self?.loadAsset(asset: avasset, thumbnail: thumbnail)
                    }
                }
            } else {
                if let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename.lowercased(), let startIndex = filename.firstIndex(of: "."), startIndex < filename.endIndex {
                    let fileExtension = String(filename[startIndex..<filename.endIndex])
                    if fileExtension.hasSuffix(".webp") || fileExtension.hasSuffix(".gif") {
                        PHImageManager.default().requestImageData(for: asset, options: nil, resultHandler: { [weak self](data, _, _, _) in
                            let tempUrl = URL.createTempUrl(fileExtension: fileExtension)
                            do {
                                try data?.write(to: tempUrl)
                                self?.animateURL = tempUrl
                                self?.photoImageView.sd_setImage(with: tempUrl, placeholderImage: nil, context: localImageContext, progress: nil, completed: { (image, _, _, _) in
                                    guard let image = image, let weakSelf = self, weakSelf.detectsQrCode else {
                                        return
                                    }
                                    weakSelf.detectQrCode(image: image)
                                })
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
    
    @IBAction func playAction(_ sender: Any) {
        if seekToZero {
            seekToZero = false
            videoView.seek(to: .zero)
        }
        let mute: Bool
        do {
            try AudioSession.shared.activate(client: self) { (session) in
                try session.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
            }
            mute = false
        } catch AudioSession.Error.insufficientPriority {
            mute = true
        } catch {
            mute = false
        }
        videoView.player.isMuted = mute
        videoView.play()
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard let asset = videoAsset as? AVURLAsset else {
            return
        }
        PHPhotoLibrary.checkAuthorization { (granted) in
            if granted {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: asset.url)
                }, completionHandler: { (success, error) in
                    DispatchQueue.main.async {
                        if success {
                            showAutoHiddenHud(style: .notification, text: Localized.CAMERA_SAVE_VIDEO_SUCCESS)
                        } else {
                            showAutoHiddenHud(style: .error, text: Localized.CAMERA_SAVE_VIDEO_FAILED)
                        }
                    }
                })
            }
        }
    }
    
    private func requestAssetImage(asset: PHAsset) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.version = .current
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestOptions, resultHandler: { [weak self] (image, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.photoImageView.image = image
            if let image = image, weakSelf.detectsQrCode {
                DispatchQueue.global().async {
                    self?.detectQrCode(image: image)
                }
            }
        })
    }
    
    private func detectQrCode(image: UIImage) {
        guard let detector = qrCodeDetector, let cgImage = image.cgImage else {
            return
        }
        let ciImage = CIImage(cgImage: cgImage)
        for case let feature as CIQRCodeFeature in detector.features(in: ciImage) {
            guard let string = feature.messageString, !string.isEmpty else {
                continue
            }
            DispatchQueue.main.async { [weak self] in
                self?.notificationController.presentQrCodeDetection(string)
            }
            break
        }
    }
    
    private func loadAsset(asset: AVAsset, thumbnail: UIImage?) {
        self.sendButton.activityIndicator.tintColor = .white
        self.videoAsset = asset
        self.playButton.isHidden = false
        self.videoView.isHidden = false
        self.photoImageView.isHidden = true
        videoView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pauseAction)))
        videoView.loadVideo(asset: asset, thumbnail: thumbnail)
        videoView.player.addObserver(self, forKeyPath: rateKey, options: [.initial, .new], context: nil)
        isObservingRate = true
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
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
        if showSaveButton {
            saveButton.isHidden = isPlayingVideo
        }
        sendButton.isHidden = isPlayingVideo
        dismissButton.isHidden = isPlayingVideo
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
            let messageId = UUID().uuidString.lowercased()
            let outputURL = AttachmentContainer.url(for: .videos, filename: messageId + ExtensionName.mp4.withDot)
            let exportSession = AssetExportSession(asset: asset, outputURL: outputURL)
            exportSession.exportAsynchronously { [weak self] in
                guard let weakSelf = self else {
                    return
                }
                DispatchQueue.main.async {
                    if exportSession.status == .completed {
                        if let composer = weakSelf.composer {
                            composer.sendMessage(type: .SIGNAL_VIDEO, messageId: messageId, value: outputURL)
                            weakSelf.navigationController?.popViewController(animated: true)
                        } else {
                            let vc = MessageReceiverViewController.instance(content: .video(outputURL))
                            weakSelf.navigationController?.pushViewController(vc, animated: true)
                        }
                    } else {
                        weakSelf.sendButton.isBusy = false
                        weakSelf.alert(Localized.CHAT_SEND_VIDEO_FAILED)
                    }
                }
            }
        } else if let image = photoImageView.image {
            if let composer = composer {
                send(image: image, to: composer)
            } else {
                let vc = MessageReceiverViewController.instance(content: .photo(image))
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        AudioSession.shared.deactivateAsynchronously(client: self, notifyOthersOnDeactivation: true)
        navigationController?.popViewController(animated: true)
    }

    class func instance(image: UIImage? = nil, asset: PHAsset? = nil, videoAsset: AVAsset? = nil, composer: ConversationMessageComposer?) -> AssetSendViewController {
       let vc = R.storyboard.chat.send_asset()!
        vc.image = image
        vc.asset = asset
        vc.videoAsset = videoAsset
        vc.composer = composer
        return vc
    }
    
    private func send(image: UIImage, to composer: ConversationMessageComposer) {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue,
                                            conversationId: composer.conversationId,
                                            userId: myUserId)
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
                let targetUrl = AttachmentContainer.url(for: .photos, filename: filename)
                do {
                    try FileManager.default.copyItem(at: assetUrl, to: targetUrl)
                    
                    message.thumbImage = image.base64Thumbnail()
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
                let targetUrl = AttachmentContainer.url(for: .photos, filename: filename)
                switch ImageUploadSanitizer.sanitizedImage(from: image) {
                case let (.some(image), .some(data)):
                    do {
                        try data.write(to: targetUrl)
                        if FileManager.default.fileSize(targetUrl.path) <= 0 {
                            fallthrough
                        }
                    } catch {
                        Logger.write(error: error)
                        fallthrough
                    }
                    message.thumbImage = image.base64Thumbnail()
                    message.mediaSize = FileManager.default.fileSize(targetUrl.path)
                    message.mediaWidth = Int(image.size.width)
                    message.mediaHeight = Int(image.size.height)
                    message.mediaMimeType = "image/jpeg"
                    message.mediaUrl = filename
                default:
                    DispatchQueue.main.async {
                        self?.sendButton.isBusy = false
                        self?.alert(Localized.CHAT_SEND_PHOTO_FAILED)
                    }
                    return
                }
            }
            SendMessageService.shared.sendMessage(message: message, ownerUser: composer.ownerUser, isGroupMessage: composer.isGroup)
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }
    
}

extension AssetSendViewController {

    @objc func applicationWillResignActive(_ sender: Notification) {
        videoView.pause()
    }

    @objc func playerItemDidReachEnd(_ notification: Notification) {
        seekToZero = true
        try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: true)
    }
    
}

extension AssetSendViewController: NotificationControllerDelegate {
    
    func notificationController(_ controller: NotificationController, didSelectNotificationWith localObject: Any?) {
        guard let string = localObject as? String, let url = URL(string: string) else {
            return
        }
        if !UrlWindow.checkUrl(url: url) {
            RecognizeWindow.instance().presentWindow(text: string)
        }
    }
    
}

extension AssetSendViewController: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .playback
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        videoView.pause()
    }
    
}
