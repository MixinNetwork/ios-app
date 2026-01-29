import UIKit
import AVKit
import PhotosUI
import MixinServices

protocol QRCodeScannerViewControllerDelegate: AnyObject {
    func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, shouldRecognizeString string: String) -> Bool
}

final class QRCodeScannerViewController: UIViewController, MixinNavigationAnimating {
    
    @IBOutlet weak var previewView: CaptureVideoPreviewView!
    @IBOutlet weak var gridView: UIImageView!
    @IBOutlet weak var gridMaskView: UIView!
    @IBOutlet weak var scanningLineView: UIView!
    @IBOutlet weak var toolbarView: UIStackView!
    
    @IBOutlet weak var navigationOverridesStatusBarConstraint: NSLayoutConstraint!
    @IBOutlet weak var showScanningLineConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideScanningLineConstraint: NSLayoutConstraint!
    
    weak var delegate: QRCodeScannerViewControllerDelegate?
    
    override var prefersStatusBarHidden: Bool {
        true
    }
    
    private let scanningLineGradientLayer = CAGradientLayer()
    private let sessionQueue = DispatchQueue(label: "one.mixin.messenger.qrscanner")
    private let metadataOutput = AVCaptureMetadataOutput()
    private let session = AVCaptureSession()
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var flashOn = false
    private var detectedQrCodes: Set<String> = []
    
    private lazy var focusIndicator: UIImageView = {
        let view = UIImageView(image: R.image.ic_focus_indicator())
        previewView.addSubview(view)
        view.isHidden = true
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
        previewView.session = session
        sessionQueue.async { [session, metadataOutput] in
            session.beginConfiguration()
            session.sessionPreset = .high
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
               let deviceInput = try? AVCaptureDeviceInput(device: device)
            {
                if session.canAddInput(deviceInput) {
                    session.addInput(deviceInput)
                    self.videoDeviceInput = deviceInput
                }
            }
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                if metadataOutput.availableMetadataObjectTypes.contains(AVMetadataObject.ObjectType.qr) {
                    metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
                    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                }
            }
            session.commitConfiguration()
        }
        gridView.mask = gridMaskView
        scanningLineGradientLayer.colors = [
            R.color.background_scan_line()!.withAlphaComponent(0).cgColor,
            R.color.background_scan_line()!.withAlphaComponent(0.6).cgColor,
        ]
        scanningLineGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        scanningLineGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        scanningLineView.layer.addSublayer(scanningLineGradientLayer)
        let focusRecognizer = UITapGestureRecognizer(target: self, action: #selector(setFocus(_:)))
        previewView.addGestureRecognizer(focusRecognizer)
        NotificationCenter.default.addObserver(self, selector: #selector(startScanAnimation), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopScanAnimation), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideFocusIndicator), name: .AVCaptureDeviceSubjectAreaDidChange, object: nil)
        startScanAnimation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [session] in
            session.startRunning()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sessionQueue.async { [session] in
            session.stopRunning()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if scanningLineGradientLayer.bounds.size != scanningLineView.bounds.size {
            scanningLineGradientLayer.frame = CGRect(origin: .zero, size: scanningLineView.bounds.size)
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if view.safeAreaInsets.top > 24 {
            navigationOverridesStatusBarConstraint.priority = .defaultLow
        } else {
            navigationOverridesStatusBarConstraint.priority = .defaultHigh
        }
    }
    
    @IBAction func backAction(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func albumAction(_ sender: Any) {
        sessionQueue.async { [session] in
            session.stopRunning()
        }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @IBAction func changeFlashAction(_ sender: Any) {
        updateTorchAndCameraFlashButton(toggleFlashMode: true)
    }
    
    @objc private func setFocus(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }
        guard let device = videoDeviceInput?.device, device.isFocusPointOfInterestSupported else {
            hideFocusIndicator()
            return
        }
        let location = recognizer.location(in: previewView)
        let poi = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = poi
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = poi
            device.exposureMode = .continuousAutoExposure
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
            focusIndicator.layer.removeAllAnimations()
            focusIndicator.center = location
            focusIndicator.transform = .identity
            focusIndicator.alpha = 1
            focusIndicator.isHidden = false
            let fadeOutSelector = #selector(fadeOutFocusIndicator)
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: fadeOutSelector, object: nil)
            UIView.animate(withDuration: 0.3, animations: {
                self.focusIndicator.transform = CGAffineTransform(scaleX: 0.56, y: 0.56)
            }) { (_) in
                self.perform(fadeOutSelector, with: nil, afterDelay: 1)
            }
        } catch {
            // OK to ignore it
        }
    }
    
    @objc private func hideFocusIndicator() {
        focusIndicator.isHidden = true
    }
    
    @objc private func fadeOutFocusIndicator() {
        UIView.animate(withDuration: 0.3) {
            self.focusIndicator.alpha = 0.6
        }
    }
    
}

extension QRCodeScannerViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .hide
    }
    
}

extension QRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }
        guard let string = object.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return
        }
        guard !detectedQrCodes.contains(string) else {
            return
        }
        detectedQrCodes.insert(string)
        handleQrCodeDetection(string: string)
    }
    
}

extension QRCodeScannerViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.presentingViewController?.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else {
            sessionQueue.async { [session] in
                session.startRunning()
            }
            return
        }
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            sessionQueue.async { [session] in
                session.startRunning()
            }
            showAutoHiddenHud(style: .error, text: R.string.localizable.qr_code_not_found())
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] (image, error) in
            let string: String? = if let image = image as? UIImage {
                QRCodeDetector.detectString(image: image)
            } else {
                nil
            }
            DispatchQueue.main.async {
                if let string {
                    self?.handleQrCodeDetection(string: string)
                } else {
                    if let self {
                        self.sessionQueue.async {
                            self.session.startRunning()
                        }
                    }
                    showAutoHiddenHud(style: .error, text: R.string.localizable.qr_code_not_found())
                }
            }
        }
    }
    
}

extension QRCodeScannerViewController: UINavigationControllerDelegate {
    // Required by UIImagePickerController for no reason
}

extension QRCodeScannerViewController {
    
    private func updateTorchAndCameraFlashButton(toggleFlashMode: Bool) {
        sessionQueue.async {
            guard let deviceInput = self.videoDeviceInput else {
                return
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
                } else {
                    deviceInput.device.torchMode = .off
                }
                deviceInput.device.unlockForConfiguration()
            } catch {
                
            }
        }
    }
    
    private func handleQrCodeDetection(string: String) {
        navigationController?.popViewController(animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            if let delegate = self.delegate, !delegate.qrCodeScannerViewController(self, shouldRecognizeString: string) {
                return
            }
            UrlWindow.checkQrCodeDetection(string: string)
        }
    }
    
    @objc private func startScanAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIView.animate(withDuration: 2, delay: 0, options: [.repeat, .curveLinear]) {
                self.showScanningLineConstraint.priority = .defaultHigh
                self.hideScanningLineConstraint.priority = .defaultLow
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc private func stopScanAnimation() {
        scanningLineView.layer.removeAllAnimations()
        showScanningLineConstraint.priority = .defaultLow
        hideScanningLineConstraint.priority = .defaultHigh
    }
    
}
