import UIKit
import AVFoundation
import Photos
import SwiftMessages

enum DetechStatus {
    case detecting
    case failed
}

class CameraViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var sendButton: BouncingButton!
    @IBOutlet weak var takeButton: UIButton!
    @IBOutlet weak var saveButton: BouncingButton!
    @IBOutlet weak var backButton: BouncingButton!
    @IBOutlet weak var cameraSwapButton: BouncingButton!
    @IBOutlet weak var cameraFlashButton: BouncingButton!
    @IBOutlet weak var snapshotImageView: UIImageView!

    private let sessionQueue = DispatchQueue(label: "one.mixin.messenger.queue.camera")
    private let metadataOutput = AVCaptureMetadataOutput()
    private let session = AVCaptureSession()
    private var capturePhotoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var detectQRCode = false
    private var didTakePhoto = false
    private var photoCaptureProcessor: PhotoCaptureProcessor?
    private var cameraPosition = AVCaptureDevice.Position.unspecified
    private lazy var shutterAnimationView = ShutterAnimationView()
    private var fromWithdrawal = false
    private var flashOn = false
    private var addressCallback: ((String) -> Void)?

    private lazy var videoDeviceDiscoverySession: AVCaptureDevice.DiscoverySession = {
        if #available(iOS 10.2, *) {
            return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: AVMediaType.video, position: .unspecified)
        } else {
            return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDuoCamera], mediaType: AVMediaType.video, position: .unspecified)
        }
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        previewView.session = session
        sessionQueue.async {
            self.configureSession()
        }

        NotificationCenter.default.addObserver(forName: .WindowDidDisappear, object: nil, queue: .main) { [weak self] (_) in
            self?.detectQRCode = false
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
        detectQRCode = false
        loadingView.stopAnimating()
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
        guard !didTakePhoto, !detectQRCode else {
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

extension CameraViewController {

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified), let deviceInput = try? AVCaptureDeviceInput(device: device) {
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
                videoDeviceInput = deviceInput
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
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !detectQRCode, !didTakePhoto else {
            return
        }
        detectQRCode = true
        guard metadataObjects.count > 0, let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            detectQRCode = false
            return
        }
        guard let urlString = object.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty else {
            detectQRCode = false
            return
        }

        if fromWithdrawal, let address = filterAddress(urlString: urlString) {
            addressCallback?(address)
            navigationController?.popViewController(animated: true)
            return
        }

        guard let url = URL(string: urlString), UrlWindow.checkUrl(url: url) else {
            RecognizeWindow.instance().presentWindow(text: urlString)
            navigationController?.popViewController(animated: true)
            return
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
