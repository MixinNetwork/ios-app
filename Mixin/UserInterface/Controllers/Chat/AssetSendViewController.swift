import UIKit
import WebKit
import Photos
import YYImage
import FirebaseMLVision

class AssetSendViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var photoImageView: YYAnimatedImageView!
    @IBOutlet weak var videoView: AssetSendVideoView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var sendButton: StateResponsiveButton!
    @IBOutlet weak var dismissButton: BouncingButton!
    
    var detectsQrCode = false
    var showSaveButton = false
    
    private weak var dataSource: ConversationDataSource?

    private let rateKey = "rate"

    private var image: UIImage?
    private var asset: PHAsset?
    private var animateURL: URL?
    private var videoAsset: AVAsset?
    private var isObservingRate = false
    private var seekToZero = false
    private var qrCodeString: String?
    
    private lazy var notificationController = NotificationController(delegate: self)
    private lazy var qrcodeDetector = Vision.vision().barcodeDetector(options: VisionBarcodeDetectorOptions(formats: .qrCode))
    private lazy var videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 1280,
        AVVideoHeightKey: 720,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 1500000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
        ]
    ]
    private lazy var audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 128000
    ]
    
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
        AudioManager.shared.pause()
        if seekToZero {
            seekToZero = false
            videoView.seek(to: .zero)
        }
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
        let image = VisionImage(image: image)
        qrcodeDetector.detect(in: image) { [weak self] (features, error) in
            guard let weakSelf = self else {
                return
            }
            guard error == nil else {
                return
            }
            guard let string = features?.first?.rawValue else {
                return
            }
            weakSelf.qrCodeString = string
            weakSelf.notificationController.present(urlString: string)
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
            let messageId = UUID().uuidString.lowercased()
            let outputURL = AttachmentContainer.url(for: .videos, filename: messageId + ExtensionName.mp4.withDot)
            let exportSession = AssetExportSession(asset: asset, videoSettings: videoSettings, audioSettings: audioSettings, outputURL: outputURL)
            exportSession.exportAsynchronously { [weak self] in
                guard let weakSelf = self else {
                    return
                }
                DispatchQueue.main.async {
                    if exportSession.status == .completed {
                        if let dataSource = weakSelf.dataSource {
                            dataSource.sendMessage(type: .SIGNAL_VIDEO, messageId: messageId, value: outputURL)
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
            if let dataSource = dataSource {
                send(image: image, to: dataSource)
            } else {
                let vc = MessageReceiverViewController.instance(content: .photo(image))
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    class func instance(image: UIImage? = nil, asset: PHAsset? = nil, videoAsset: AVAsset? = nil, dataSource: ConversationDataSource?) -> AssetSendViewController {
       let vc = R.storyboard.chat.send_asset()!
        vc.image = image
        vc.asset = asset
        vc.videoAsset = videoAsset
        vc.dataSource = dataSource
        return vc
    }
    
    private func send(image: UIImage, to dataSource: ConversationDataSource) {
        var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue, conversationId: dataSource.conversationId, userId: myUserId)
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
                let targetPhoto = image.scaleForUpload()
                if targetPhoto.saveToFile(path: targetUrl), FileManager.default.fileSize(targetUrl.path) > 0 {
                    message.thumbImage = targetPhoto.base64Thumbnail()
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

extension AssetSendViewController {

    @objc func applicationWillResignActive(_ sender: Notification) {
        videoView.pause()
    }

    @objc func playerItemDidReachEnd(_ notification: Notification) {
        seekToZero = true
    }
}

extension AssetSendViewController: NotificationControllerDelegate {
    
    func notificationControllerDidSelectNotification(_ controller: NotificationController) {
        guard let string = qrCodeString, let url = URL(string: string) else {
            return
        }
        if !UrlWindow.checkUrl(url: url) {
            RecognizeWindow.instance().presentWindow(text: string)
        }
    }
    
}
