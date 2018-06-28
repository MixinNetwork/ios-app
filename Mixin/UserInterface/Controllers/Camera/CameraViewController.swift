import UIKit
import AVFoundation
import Photos
import SwiftMessages
import AVKit

enum DetechStatus {
    case detecting
    case failed
}

class CameraViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var sendButton: BouncingButton!
    @IBOutlet weak var takeButton: RecordButton!
    @IBOutlet weak var saveButton: BouncingButton!
    @IBOutlet weak var backButton: BouncingButton!
    @IBOutlet weak var cameraSwapButton: BouncingButton!
    @IBOutlet weak var cameraFlashButton: BouncingButton!
    @IBOutlet weak var snapshotImageView: UIImageView!
    @IBOutlet weak var qrcodeContentLabel: UILabel!
    @IBOutlet weak var qrcodeView: UIVisualEffectView!
    @IBOutlet weak var qrcodeTipsView: UIView!
    @IBOutlet weak var toolbarView: UIView!
    @IBOutlet weak var timeView: UIView!
    @IBOutlet weak var recordingRedDotView: UIView!
    @IBOutlet weak var timeLabel: UILabel!

    @IBOutlet weak var qrcodeNotificationTopConstraint: NSLayoutConstraint!

    private let sessionQueue = DispatchQueue(label: "one.mixin.messenger.queue.camera")
    private let metadataOutput = AVCaptureMetadataOutput()
    private let session = AVCaptureSession()
    private let captureVideoOutput = AVCaptureMovieFileOutput()
    private var capturePhotoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var audioDeviceInput: AVCaptureDeviceInput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var didTakePhoto = false
    private var photoCaptureProcessor: PhotoCaptureProcessor?
    private var cameraPosition = AVCaptureDevice.Position.unspecified
    private lazy var shutterAnimationView = ShutterAnimationView()
    private var fromWithdrawal = false
    private var flashOn = false
    private var addressCallback: ((String) -> Void)?
    private var detectQRCodes = [String]()
    private var detectLock = NSLock()
    private var detectText = ""
    private var recordTimer: Timer?
    private var isGrantedAudioRecordPermission = false

    private lazy var videoDeviceDiscoverySession: AVCaptureDevice.DiscoverySession = {
        if #available(iOS 10.2, *) {
            return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: AVMediaType.video, position: .unspecified)
        } else {
            return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDuoCamera], mediaType: AVMediaType.video, position: .unspecified)
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        prepareNotification()
        previewView.session = session
        sessionQueue.async {
            self.configureSession()
        }

        if !CommonUserDefault.shared.isCameraQRCodeTips {
            qrcodeTipsView.isHidden = false
        }
        prepareRecord()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sessionQueue.async {
            self.session.startRunning()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session.stopRunning()
        loadingView.stopAnimating()
    }

    @IBAction func hideTipsAction(_ sender: Any) {
        CommonUserDefault.shared.isCameraQRCodeTips = true
        qrcodeTipsView.isHidden = true
    }


    @IBAction func savePhotoAction(_ sender: Any) {
        guard didTakePhoto, let photo = photoCaptureProcessor?.photo else {
            return
        }

        saveButton.isEnabled = false
        sendButton.isEnabled = false
        PHPhotoLibrary.checkAuthorization { [weak self](authorized) in
            guard let weakSelf = self else {
                return
            }
            guard authorized else {
                weakSelf.saveButton.isEnabled = true
                weakSelf.sendButton.isEnabled = true
                return
            }
            weakSelf.savePhoto(photo: photo)
        }
    }

    private func savePhoto(photo: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: photo)
        }, completionHandler: { [weak self](success: Bool, error: Error?) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                if success {
                    weakSelf.displaySnapshotView(show: false)
                    weakSelf.didTakePhoto = false
                    SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_SUCCESS, backgroundColor: .hintGreen)
                } else {
                    SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_FAILED, backgroundColor: .hintRed)
                }
                weakSelf.saveButton.isEnabled = true
                weakSelf.sendButton.isEnabled = true
            }
        })
    }

    @IBAction func changeFlashAction(_ sender: Any) {
        updateTorchAndCameraFlashButton(toggleFlashMode: true)
    }

    @IBAction func changeCameraAction(_ sender: Any) {
        guard let deviceInput = self.videoDeviceInput else {
            return
        }
        cameraSwapButton.isEnabled = false
        sessionQueue.async {
            defer {
                DispatchQueue.main.async {
                    self.cameraSwapButton.isEnabled = true
                }
            }
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType

            switch deviceInput.device.position {
            case .unspecified, .front:
                preferredPosition = .back
                if #available(iOS 10.2, *) {
                    preferredDeviceType = .builtInDualCamera
                } else {
                    preferredDeviceType = .builtInDuoCamera
                }
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
            }

            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice?
            if let device = devices.filter({ $0.position == preferredPosition && $0.deviceType == preferredDeviceType }).first {
                newVideoDevice = device
            } else if let device = devices.filter({ $0.position == preferredPosition }).first {
                newVideoDevice = device
            }

            guard let inputDevice = newVideoDevice, let videoDeviceInput = try? AVCaptureDeviceInput(device: inputDevice) else {
                return
            }

            self.cameraPosition = preferredPosition
            self.session.beginConfiguration()
            self.session.removeInput(deviceInput)
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                self.session.addInput(deviceInput)
            }

            self.session.commitConfiguration()
        }
    }

    @IBAction func takeAction(_ sender: Any) {
        guard !didTakePhoto else {
            return
        }
        didTakePhoto = true

        displaySnapshotView(show: true)
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation
        sessionQueue.async {
            if let photoOutputConnection = self.capturePhotoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
            }

            let size = UIScreen.main.bounds.size
            let photoSettings = AVCapturePhotoSettings()
            let previewPixelType = photoSettings.availablePreviewPhotoPixelFormatTypes.first!
            let previewFormat: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                                                 kCVPixelBufferWidthKey as String: Int(size.width),
                                                 kCVPixelBufferHeightKey as String: Int(size.height)]
            photoSettings.previewPhotoFormat = previewFormat
            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.flashMode = self.flashOn ? .on : .off
            
            let photoCaptureProcessor = PhotoCaptureProcessor(completionHandler: { [weak self] in
                guard let weakSelf = self else {
                    return
                }
                guard let photo = weakSelf.photoCaptureProcessor?.photo else {
                    weakSelf.didTakePhoto = false
                    weakSelf.displaySnapshotView(show: false)
                    return
                }

                weakSelf.snapshotImageView.image = photo
                weakSelf.snapshotImageView.isHidden = false
                weakSelf.updateTorchAndCameraFlashButton(toggleFlashMode: false)
            })
            photoCaptureProcessor.cameraPosition = self.cameraPosition

            self.photoCaptureProcessor = photoCaptureProcessor
            self.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }

    @IBAction func sendAction(_ sender: Any) {
        guard let photo = snapshotImageView.image else {
            return
        }
        navigationController?.pushViewController(SendToViewController.instance(photo: photo), animated: true)
    }

    @IBAction func backAction(_ sender: UIButton) {
        if didTakePhoto {
            didTakePhoto = false
            displaySnapshotView(show: false)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    class func instance(fromWithdrawal: Bool = false, addressCallback: ((String) -> Void)? = nil) -> UIViewController {
        let vc = Storyboard.camera.instantiateViewController(withIdentifier: "camera") as! CameraViewController
        vc.fromWithdrawal = fromWithdrawal
        vc.addressCallback = addressCallback
        return vc
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {

    private let completionHandler: () -> Void

    private(set) var photo: UIImage?

    var cameraPosition = AVCaptureDevice.Position.unspecified

    init(completionHandler: @escaping () -> Void) {
        self.completionHandler = completionHandler
    }

    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto rawSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {

        defer {
            completionHandler()
        }

        guard error == nil else {
            return
        }
        guard let sampleBuffer = rawSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) else {
            return
        }

        if cameraPosition == .front, let dataProvider = CGDataProvider(data: dataImage as CFData), let cgImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            self.photo = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
        } else {
            self.photo = UIImage(data: dataImage)
        }
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {

    func prepareRecord() {
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(recordViewAction))
        longPressRecognizer.minimumPressDuration = 0.15
        takeButton.addGestureRecognizer(longPressRecognizer)
        takeButton.longPressRecognizer = longPressRecognizer

        timeLabel.shadowColor = UIColor.black
        timeLabel.shadowOffset = CGSize(width: 0.3, height: 0.3)
    }

    @objc func recordViewAction(gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            startRecordingIfGranted()
            takeButton.startAnimation { [weak self] in
                self?.startRecord()
            }
            timeLabel.text = mediaDurationFormatter.string(from: 0)
            displayMainUI(false)
            self.recordTimer?.invalidate()
            let timer = Timer(timeInterval: 0.5,
                              target: self,
                              selector: #selector(updateTimeLabelAction(_:)),
                              userInfo: nil,
                              repeats: true)
            RunLoop.main.add(timer, forMode: .commonModes)
            recordTimer = timer
            startRedDotAnimation()
        case .ended, .cancelled, .failed:
            takeButton.resetAnimation { [weak self] in
                self?.stopRecord()
            }
            displayMainUI(true)
            stopRedDotAnimation()
            recordTimer?.invalidate()
            recordTimer = nil
        default:
            break
        }
    }

    private func startRecordingIfGranted() {
        isGrantedAudioRecordPermission = false
        switch AVAudioSession.sharedInstance().recordPermission() {
        case .denied:
            alertSettings(Localized.PERMISSION_DENIED_MICROPHONE)
        case .granted:
            isGrantedAudioRecordPermission = true
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (_) in })
        }
    }

    private func startRecord() {
        guard captureVideoOutput.connection(with: .video)?.isActive ?? false else {
            return
        }

        captureVideoOutput.startRecording(to: URL.createTempUrl(fileExtension: "mov"), recordingDelegate: self)
    }

    private func stopRecord() {
        guard captureVideoOutput.isRecording else {
            return
        }
        captureVideoOutput.stopRecording()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        defer {
            takeButton.autoStopAction()
        }
        guard error == nil, isGrantedAudioRecordPermission else {
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }
        let asset = AVAsset(url: outputFileURL)
        guard asset.duration.isValid, asset.duration.seconds >= 1 else {
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }

        navigationController?.pushViewController(AssetSendViewController.instance(videoAsset: asset, dataSource: nil), animated: true)
    }

    private func displayMainUI(_ display: Bool) {
        UIView.animate(withDuration: 0.15) {
            self.toolbarView.alpha = display ? 1 : 0
            self.timeView.alpha = display ? 0 : 1
        }
    }

    private func startRedDotAnimation() {
        UIView.animate(withDuration: 1, delay: 0, options: [.repeat, .autoreverse], animations: {
            self.recordingRedDotView.alpha = 1
        }, completion: nil)
    }

    private func stopRedDotAnimation() {
        recordingRedDotView.layer.removeAllAnimations()
        recordingRedDotView.alpha = 0
    }

    @objc func updateTimeLabelAction(_ sender: Any) {
        guard captureVideoOutput.isRecording, captureVideoOutput.recordedDuration.isValid else {
            return
        }
        timeLabel.text = mediaDurationFormatter.string(from: captureVideoOutput.recordedDuration.seconds)
    }
}

extension CameraViewController {

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified), let deviceInput = try? AVCaptureDeviceInput(device: device) {
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
                videoDeviceInput = deviceInput
            }
        }

        if let device = AVCaptureDevice.default(for: .audio), let deviceInput = try? AVCaptureDeviceInput(device: device) {
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
                audioDeviceInput = deviceInput
            }
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            if metadataOutput.availableMetadataObjectTypes.contains(AVMetadataObject.ObjectType.qr) {
                metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            }
        }

        capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
        if session.canAddOutput(capturePhotoOutput) {
            session.addOutput(capturePhotoOutput)
        }

        captureVideoOutput.maxRecordedDuration = CMTime(seconds: 15, preferredTimescale: 30)
        if session.canAddOutput(captureVideoOutput) {
            session.addOutput(captureVideoOutput)
        }

        session.commitConfiguration()
    }

    private func displaySnapshotView(show: Bool) {
        cameraSwapButton.isHidden = show
        cameraFlashButton.isHidden = show
        saveButton.isHidden = !show
        
        if show {
            takeButton.isHidden = true
            view.addSubview(shutterAnimationView)
            shutterAnimationView.frame = takeButton.frame
            shutterAnimationView.transformToSend()
            UIView.animate(withDuration: ShutterAnimationView.animationDuration, animations: {
                self.shutterAnimationView.frame = self.sendButton.frame
            }, completion: { (finished) in
                self.sendButton.isHidden = false
                self.shutterAnimationView.removeFromSuperview()
            })
            backButton.setImage(#imageLiteral(resourceName: "ic_titlebar_back_white"), for: .normal)
        } else {
            snapshotImageView.isHidden = true
            sendButton.isHidden = true
            view.addSubview(shutterAnimationView)
            shutterAnimationView.frame = sendButton.frame
            shutterAnimationView.transformToShutter()
            UIView.animate(withDuration: ShutterAnimationView.animationDuration, animations: {
                self.shutterAnimationView.frame = self.takeButton.frame
            }, completion: { (finished) in
                self.takeButton.isHidden = false
                self.shutterAnimationView.removeFromSuperview()
            })
            backButton.setImage(#imageLiteral(resourceName: "ic_close_shadow"), for: .normal)
        }
    }
    
    private func updateTorchAndCameraFlashButton(toggleFlashMode: Bool) {
        guard let deviceInput = self.videoDeviceInput else {
            return
        }
        cameraFlashButton.isEnabled = false
        sessionQueue.async {
            defer {
                DispatchQueue.main.async {
                    self.cameraFlashButton.isEnabled = true
                }
            }
            guard deviceInput.device.isFlashAvailable && deviceInput.device.isTorchAvailable else {
                return
            }
            do {
                try deviceInput.device.lockForConfiguration()
                if toggleFlashMode {
                    self.flashOn = !self.flashOn
                }
                if self.flashOn {
                    deviceInput.device.torchMode = .on
                    DispatchQueue.main.async {
                        self.cameraFlashButton.setImage(#imageLiteral(resourceName: "ic_camera_flash"), for: .normal)
                    }
                } else {
                    deviceInput.device.torchMode = .off
                    DispatchQueue.main.async {
                        self.cameraFlashButton.setImage(#imageLiteral(resourceName: "ic_camera_flash_off"), for: .normal)
                    }
                }
                deviceInput.device.unlockForConfiguration()
            } catch {
                
            }
        }
    }

}

extension CameraViewController: AVCaptureMetadataOutputObjectsDelegate {

    private func prepareNotification() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        qrcodeView.addGestureRecognizer(panRecognizer)
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        qrcodeView.addGestureRecognizer(tapRecognizer)
    }

    @objc func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: qrcodeView)
        case .changed:
            qrcodeNotificationTopConstraint.constant = qrcodeNotificationTopConstraint.constant + recognizer.translation(in: qrcodeView).y
            recognizer.setTranslation(.zero, in: qrcodeView)
        default:
            if qrcodeNotificationTopConstraint.constant > 6 && qrcodeNotificationTopConstraint.constant < 18 {
                qrcodeNotificationTopConstraint.constant = 12
                UIView.animate(withDuration: 0.15, animations: {
                    self.view.layoutIfNeeded()
                })
            } else {
                hideNotification()
            }
        }
    }

    @objc func tapAction(_ recognizer: UIPanGestureRecognizer) {
        hideNotification()

        if let url = URL(string: detectText), UrlWindow.checkUrl(url: url) {
            return
        }
        RecognizeWindow.instance().presentWindow(text: detectText)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didTakePhoto, qrcodeTipsView.isHidden else {
            return
        }
        guard metadataObjects.count > 0, let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }
        guard let urlString = object.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty else {
            return
        }

        if fromWithdrawal, let address = filterAddress(urlString: urlString) {
            addressCallback?(address)
            navigationController?.popViewController(animated: true)
            return
        }

        detectLock.lock()
        guard !detectQRCodes.contains(urlString) else {
            detectLock.unlock()
            return
        }
        detectQRCodes.append(urlString)
        detectLock.unlock()

        detectText = urlString

        if let url = URL(string: urlString), let mixinURL = MixinURL(url: url) {
            switch mixinURL {
            case .codes, .pay, .users, .transfer:
                showNotification(text: Localized.CAMERA_QRCODE_CODES)
            case .send:
                showNotification(text: urlString)
            case .unknown:
                showNotification(text: urlString)
            }
        } else {
            showNotification(text: urlString)
        }
    }

    private func showNotification(text: String) {
        let animateBlock = {
            self.qrcodeContentLabel.text = text
            self.qrcodeView.isHidden = false
            self.qrcodeNotificationTopConstraint.constant = 12
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 5, options: [], animations: {
                self.view.layoutIfNeeded()
            }) { (_) in

            }
        }
        if !qrcodeView.isHidden {
            UIView.animate(withDuration: 0.15, animations: {
                self.qrcodeView.transform = CGAffineTransform(translationX: 0, y: 10)
            }, completion: { (finished) in
                self.qrcodeContentLabel.text = text
                UIView.animate(withDuration: 0.15, animations: {
                    self.qrcodeView.transform = .identity
                })
            })
        } else {
            animateBlock()
        }
    }

    private func hideNotification() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.qrcodeNotificationTopConstraint.constant = -86
            self.view.layoutIfNeeded()
        }) { (_) in
            self.qrcodeView.isHidden = true
        }
    }

    private func filterAddress(urlString: String) -> String? {
        guard urlString.hasPrefix("iban:XE") || urlString.hasPrefix("IBAN:XE") else {
            return urlString
        }
        guard urlString.count >= 20 else {
            return nil
        }

        let endIndex = urlString.index(of: "?") ?? urlString.endIndex
        let accountIdentifier = urlString[urlString.index(urlString.startIndex, offsetBy: 9)..<endIndex]

        guard let address = accountIdentifier.lowercased().base36to16() else {
            return nil
        }
        return "0x\(address)"
    }
    
}

fileprivate extension String {

    static let base36Alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

    static var base36AlphabetMap: [Character: Int] = {
        var reverseLookup = [Character: Int]()
        for characterIndex in 0..<String.base36Alphabet.count {
            let character = base36Alphabet[base36Alphabet.index(base36Alphabet.startIndex, offsetBy: characterIndex)]
            reverseLookup[character] = characterIndex
        }
        return reverseLookup
    }()

    func base36to16() -> String? {
        var bytes = [Int]()
        for character in self {
            guard var carry = String.base36AlphabetMap[character] else {
                return nil
            }

            for byteIndex in 0..<bytes.count {
                carry += bytes[byteIndex] * 36
                bytes[byteIndex] = carry & 0xff
                carry >>= 8
            }

            while carry > 0 {
                bytes.append(carry & 0xff)
                carry >>= 8
            }
        }
        return bytes.reversed().map { String(format: "%02hhx", $0) }.joined()
    }

}
