import UIKit
import WebKit
import Photos

class AssetSendViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var videoView: GalleryVideoView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var sendButton: StateResponsiveButton!
    @IBOutlet weak var dismissButton: BouncingButton!

    private weak var dataSource: ConversationDataSource?

    private let rateKey = "rate"

    private var image: UIImage?
    private var asset: PHAsset?
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
                let requestOptions = PHImageRequestOptions()
                requestOptions.version = .unadjusted
                requestOptions.isSynchronous = true
                requestOptions.deliveryMode = .highQualityFormat
                requestOptions.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestOptions, resultHandler: { [weak self](image, _) in
                    self?.image = image
                    self?.photoImageView.image = image
                })
            }
        }
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
        if let image = self.image {
            dataSource?.sendMessage(type: .SIGNAL_IMAGE, value: image.scaleForUpload())
            navigationController?.popViewController(animated: true)
        } else if let asset = self.videoAsset {
            guard !sendButton.isBusy else {
                return
            }
            sendButton.isBusy = true
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else {
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.CHAT_SEND_VIDEO_FAILED)
                return
            }
            let filename = UUID().uuidString.lowercased()
            let outputURL = MixinFile.url(ofChatDirectory: .videos, filename: filename + ExtensionName.mp4.withDot)
            exportSession.outputFileType = .mp4
            exportSession.outputURL = outputURL
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.exportAsynchronously(completionHandler: { [weak self] in
                guard exportSession.status == .completed else {
                    NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.CHAT_SEND_VIDEO_FAILED)
                    return
                }
                DispatchQueue.main.async {
                    self?.dataSource?.sendMessage(type: .SIGNAL_VIDEO, value: outputURL, asset: asset)
                    self?.navigationController?.popViewController(animated: true)
                }
            })
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    class func instance(image: UIImage? = nil, asset: PHAsset? = nil, dataSource: ConversationDataSource?) -> UIViewController {
       let vc = Storyboard.chat.instantiateViewController(withIdentifier: "send_asset") as! AssetSendViewController
        vc.image = image
        vc.asset = asset
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
