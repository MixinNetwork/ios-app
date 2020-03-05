import UIKit
import WebKit
import Photos
import Alamofire
import MixinServices

class WebViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var statusBarBackgroundView: UIView!
    @IBOutlet weak var titleWrapperView: UIView!
    @IBOutlet weak var titleImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    @IBOutlet weak var buttonsWrapperView: UIView!
    @IBOutlet weak var buttonsBackgroundView: UIView!
    @IBOutlet weak var buttonsBackgroundEffectView: UIVisualEffectView!
    @IBOutlet weak var buttonsSeparatorLineView: UIView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var suspicionView: UIView!
    @IBOutlet weak var edgePanGestureRecognizer: WebViewScreenEdgePanGestureRecognizer!
    
    @IBOutlet weak var showPageTitleConstraint: NSLayoutConstraint!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
    }
    
    var config: WKWebViewConfiguration {
        WKWebViewConfiguration()
    }
    
    private(set) lazy var webView: WKWebView = {
        let frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        return WKWebView(frame: frame, configuration: config)
    }()
    
    private(set) var isBeingDismissedAsChild = false
    
    private let buttonDarkColor = UIColor(displayP3RgbValue: 0x2E2F31)
    private let textDarkColor = UIColor(displayP3RgbValue: 0x333333)
    
    private var statusBarStyle = UIStatusBarStyle.default
    private var imageRequest: DataRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateBackground(pageThemeColor: .background)
        buttonsBackgroundView.layer.borderWidth = 1
        webViewWrapperView.addSubview(webView)
        webView.snp.makeEdgesEqualToSuperview()
        webView.isOpaque = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.panGestureRecognizer.require(toFail: edgePanGestureRecognizer)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        imageRequest?.cancel()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        parent?.setNeedsStatusBarAppearanceUpdate()
        parent?.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.parent?.setNeedsStatusBarAppearanceUpdate()
            self.parent?.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }
    
    @IBAction func moreAction(_ sender: Any) {
        
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss()
    }

    @IBAction func continueAction(_ sender: Any) {
        
    }

    
    @IBAction func screenEdgePanAction(_ recognizer: WebViewScreenEdgePanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if view.safeAreaInsets.top > 20 {
                contentView.layer.cornerRadius = 39
            } else {
                contentView.layer.cornerRadius = 20
            }
        case .changed:
            let scale = 1 - 0.2 * recognizer.fractionComplete
            contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        case .ended:
            dismiss()
        case .cancelled:
            UIView.animate(withDuration: 0.25, animations: {
                self.contentView.transform = .identity
            }, completion: { _ in
                self.contentView.layer.cornerRadius = 0
            })
        default:
            break
        }
    }
    
    @IBAction func extractImageAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        imageRequest?.cancel()
        let location = round(recognizer.location(in: webView))
        let script = "document.elementFromPoint(\(location.x), \(location.y)).src"
        webView.evaluateJavaScript(script) { (urlString, error) in
            guard error == nil, let urlString = urlString as? String else {
                return
            }
            self.imageRequest = Alamofire.request(urlString).responseData(completionHandler: { [weak self] (response) in
                guard recognizer.state == .began || recognizer.state == .changed else {
                    return
                }
                guard case let .success(data) = response.result, let image = UIImage(data: data) else {
                    return
                }
                DispatchQueue.main.async {
                    self?.presentAlertController(for: image)
                }
            })
        }
    }
    
    func updateBackground(pageThemeColor: UIColor) {
        statusBarBackgroundView.backgroundColor = pageThemeColor
        titleWrapperView.backgroundColor = pageThemeColor
        webView.backgroundColor = pageThemeColor
        
        let themeColorIsDark = pageThemeColor.w3cLightness < 0.5
        buttonsBackgroundEffectView.effect = themeColorIsDark ? .darkBlur : .extraLightBlur
        titleLabel.textColor = themeColorIsDark ? .white : textDarkColor
        
        let tintColor: UIColor = themeColorIsDark ? .white : buttonDarkColor
        moreButton.tintColor = tintColor
        dismissButton.tintColor = tintColor
        
        let outlineColor: UIColor = themeColorIsDark
            ? UIColor.white.withAlphaComponent(0.1)
            : UIColor.black.withAlphaComponent(0.06)
        buttonsSeparatorLineView.backgroundColor = outlineColor
        buttonsBackgroundView.layer.borderColor = outlineColor.cgColor
        
        if #available(iOS 13.0, *) {
            statusBarStyle = themeColorIsDark ? .lightContent : .darkContent
        } else {
            statusBarStyle = themeColorIsDark ? .lightContent : .default
        }
        setNeedsStatusBarAppearanceUpdate()
    }
    
    private func dismiss() {
        if let parent = parent {
            isBeingDismissedAsChild = true
            parent.setNeedsStatusBarAppearanceUpdate()
            UIView.animate(withDuration: 0.5, animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.center.y = parent.view.bounds.height * 3 / 2
            }) { (_) in
                self.willMove(toParent: nil)
                self.view.removeFromSuperview()
                self.removeFromParent()
            }
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    private func presentAlertController(for image: UIImage) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { (_) in
            PHPhotoLibrary.checkAuthorization { (authorized) in
                if authorized {
                    PHPhotoLibrary.saveImageToLibrary(image: image)
                }
            }
        }))
        
        if let detector = qrCodeDetector, let cgImage = image.cgImage {
            let ciImage = CIImage(cgImage: cgImage)
            for case let feature as CIQRCodeFeature in detector.features(in: ciImage) {
                guard let string = feature.messageString else {
                    continue
                }
                controller.addAction(UIAlertAction(title: Localized.SCAN_QR_CODE, style: .default, handler: { (_) in
                    if let url = URL(string: string), UrlWindow.checkUrl(url: url, clearNavigationStack: false) {
                        
                    } else {
                        RecognizeWindow.instance().presentWindow(text: string)
                    }
                }))
                break
            }
        }
        
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(controller, animated: true, completion: nil)
    }
    
}

extension WebViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Extract image recognizer
        return true
    }
    
}
