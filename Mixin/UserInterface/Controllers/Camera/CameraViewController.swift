import UIKit
import AVFoundation
import Photos
import AVKit

enum DetechStatus {
    case detecting
    case failed
}

protocol CameraViewControllerDelegate: class {
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool
}

class CameraViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var sendButton: BouncingButton!
    @IBOutlet weak var takeButton: RecordButton!
    @IBOutlet weak var saveButton: BouncingButton!
    @IBOutlet weak var backButton: BouncingButton!
    @IBOutlet weak var albumButton: UIButton!
    @IBOutlet weak var switchCameraButton: BouncingButton!
    @IBOutlet weak var cameraFlashButton: BouncingButton!
    @IBOutlet weak var snapshotImageView: UIImageView!
    @IBOutlet weak var qrcodeTipsView: UIView!
    @IBOutlet weak var toolbarView: UIView!
    @IBOutlet weak var timeView: UIView!
    @IBOutlet weak var recordingRedDotView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    
    @IBOutlet weak var navigationOverridesStatusBarConstraint: NSLayoutConstraint!
    
    weak var delegate: CameraViewControllerDelegate?
    
    var scanQrCodeOnly = false
    
    private let sessionQueue = DispatchQueue(label: "one.mixin.messenger.queue.camera")
    private let metadataOutput = AVCaptureMetadataOutput()
    private let session = AVCaptureSession()
    private let captureVideoOutput = AVCaptureMovieFileOutput()
    
    private var capturePhotoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var didTakePhoto = false
    private var photoCaptureProcessor: PhotoCaptureProcessor?
    private var cameraPosition = AVCaptureDevice.Position.unspecified
    private var flashOn = false
    private var detectedQRCodes = Set<String>()
    private var detectText = ""
    private var recordTimer: Timer?
    private var audioRecordPermissionIsGranted: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    private lazy var notificationController = NotificationController(delegate: self)
    private lazy var shutterAnimationView = ShutterAnimationView()
    private lazy var videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera],
                                                                                    mediaType: AVMediaType.video,
                                                                                    position: .unspecified)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.session = session
        sessionQueue.async {
            self.configureSession()
        }

        if !AppGroupUserDefaults.User.hasShownCameraQrCodeTips {
            qrcodeTipsView.isHidden = false
        }
        prepareRecord()
        if scanQrCodeOnly {
            sendButton.isHidden = true
            takeButton.isHidden = true
            saveButton.isHidden = true
            albumButton.isHidden = true
            switchCameraButton.isHidden = true
        }
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
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if view.safeAreaInsets.top > 24 {
            navigationOverridesStatusBarConstraint.priority = .defaultLow
        } else {
            navigationOverridesStatusBarConstraint.priority = .defaultHigh
        }
    }
    
    @IBAction func hideTipsAction(_ sender: Any) {
        AppGroupUserDefaults.User.hasShownCameraQrCodeTips = true
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
    
    @IBAction func albumAction(_ sender: Any) {
        PHPhotoLibrary.checkAuthorization { (granted) in
            if granted {
                let vc = PhotoAssetPickerNavigationController.instance(pickerDelegate: self)
                self.present(vc, animated: true, completion: nil)
            }
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
                    showAutoHiddenHud(style: .notification, text: Localized.CAMERA_SAVE_PHOTO_SUCCESS)
                } else {
                    showAutoHiddenHud(style: .error, text: Localized.CAMERA_SAVE_PHOTO_FAILED)
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
        switchCameraButton.isEnabled = false
        sessionQueue.async {
            defer {
                DispatchQueue.main.async {
                    self.switchCameraButton.isEnabled = true
                }
            }
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType

            switch deviceInput.device.position {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
            @unknown default:
                return
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

            if let connection = self.captureVideoOutput.connection(with: .video), connection.isVideoMirroringSupported {
                connection.isVideoMirrored = preferredPosition == .front
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
        let vc = MessageReceiverViewController.instance(content: .photo(photo))
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func backAction(_ sender: UIButton) {
        if didTakePhoto {
            didTakePhoto = false
            displaySnapshotView(show: false)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    class func instance() -> CameraViewController {
        R.storyboard.camera.camera()!
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
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            completionHandler()
        }
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        if cameraPosition == .front, let provider = CGDataProvider(data: data as CFData), let cgImage = CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            self.photo = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
        } else {
            self.photo = UIImage(data: data)
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
            if !audioRecordPermissionIsGranted {
                askForAudioRecordPermission()
            } else {
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
                RunLoop.main.add(timer, forMode: .common)
                recordTimer = timer
                startRedDotAnimation()
            }
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

    private func askForAudioRecordPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .denied:
            alertSettings(Localized.PERMISSION_DENIED_MICROPHONE)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                if granted {
                    DispatchQueue.main.async {
                        self.addAudioDeviceInputIfNeeded()
                    }
                }
            })
        case .granted:
            break
        @unknown default:
            break
        }
    }

    private func startRecord() {
        guard captureVideoOutput.connection(with: .video)?.isActive ?? false else {
            return
        }
        albumButton.isHidden = true
        switchCameraButton.isHidden = true
        captureVideoOutput.startRecording(to: URL.createTempUrl(fileExtension: "mov"), recordingDelegate: self)
    }

    private func stopRecord() {
        guard captureVideoOutput.isRecording else {
            return
        }
        albumButton.isHidden = false
        switchCameraButton.isHidden = false
        captureVideoOutput.stopRecording()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        defer {
            takeButton.autoStopAction()
        }
        guard error == nil, audioRecordPermissionIsGranted else {
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }
        let asset = AVAsset(url: outputFileURL)
        guard asset.duration.isValid, asset.duration.seconds >= 1 else {
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }
        
        let vc = AssetSendViewController.instance(videoAsset: asset, dataSource: nil)
        vc.showSaveButton = true
        navigationController?.pushViewController(vc, animated: true)
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

        if audioRecordPermissionIsGranted {
            addAudioDeviceInputIfNeeded()
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            if metadataOutput.availableMetadataObjectTypes.contains(AVMetadataObject.ObjectType.qr) {
                metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            }
        }

        capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
        if session.canAddOutput(capturePhotoOutput) {
            session.addOutput(capturePhotoOutput)
        }

        captureVideoOutput.maxRecordedDuration = CMTime(seconds: 15, preferredTimescale: 30)
        if session.canAddOutput(captureVideoOutput) {
            session.addOutput(captureVideoOutput)
        }

        session.commitConfiguration()
    }
    
    private func addAudioDeviceInputIfNeeded() {
        guard audioDeviceInput == nil, let device = AVCaptureDevice.default(for: .audio), let deviceInput = try? AVCaptureDeviceInput(device: device), session.canAddInput(deviceInput) else {
            return
        }
        session.addInput(deviceInput)
        audioDeviceInput = deviceInput
    }

    private func displaySnapshotView(show: Bool) {
        switchCameraButton.isHidden = show
        cameraFlashButton.isHidden = show
        saveButton.isHidden = !show
        albumButton.isHidden = show
        
        let shutterAnimationStartFrame = takeButton.convert(takeButton.bounds, to: view)
        let shutterAnimationEndFrame = sendButton.convert(sendButton.bounds, to: view)
        if show {
            takeButton.isHidden = true
            view.addSubview(shutterAnimationView)
            shutterAnimationView.frame = shutterAnimationStartFrame
            shutterAnimationView.transformToSend()
            UIView.animate(withDuration: ShutterAnimationView.animationDuration, animations: {
                self.shutterAnimationView.frame = shutterAnimationEndFrame
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
                self.shutterAnimationView.frame = shutterAnimationStartFrame
            }, completion: { (finished) in
                self.takeButton.isHidden = false
                self.shutterAnimationView.removeFromSuperview()
            })
            backButton.setImage(R.image.ic_camera_close(), for: .normal)
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
                        self.cameraFlashButton.setImage(#imageLiteral(resourceName: "ic_camera_flash_on"), for: .normal)
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
        guard !detectedQRCodes.contains(urlString) else {
            return
        }
        
        detectedQRCodes.insert(urlString)
        
        if let delegate = delegate, !delegate.cameraViewController(self, shouldRecognizeString: urlString) {
            return
        }

        detectText = urlString
        notificationController.present(urlString: urlString)
    }
    
}

extension CameraViewController: PhotoAssetPickerDelegate {
    
    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset) {
        let vc = AssetSendViewController.instance(asset: asset, dataSource: nil)
        vc.detectsQrCode = true
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension CameraViewController: NotificationControllerDelegate {
    
    func notificationControllerDidSelectNotification(_ controller: NotificationController) {
        AppGroupUserDefaults.User.hasPerformedQrCodeScanning = true
        if let url = URL(string: detectText), UrlWindow.checkUrl(url: url) {
            return
        }
        RecognizeWindow.instance().presentWindow(text: detectText)
    }
    
}
