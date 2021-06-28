import UIKit
import WebKit
import Photos
import Alamofire
import MixinServices

class WebViewController: FullscreenPopupViewController {
    
    static let didDismissNotification = Notification.Name("one.mixin.messenger.WebViewController.didDismiss")
    
    @IBOutlet weak var statusBarBackgroundView: UIView!
    @IBOutlet weak var titleWrapperView: UIView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    
    @IBOutlet weak var showPageTitleConstraint: NSLayoutConstraint!
    
    weak var webContentView: UIView!
    weak var webView: WKWebView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
    }
    
    var webViewConfiguration: WKWebViewConfiguration {
        return WKWebViewConfiguration()
    }
    
    private let textDarkColor = UIColor(displayP3RgbValue: 0x333333)
    
    private var statusBarStyle = UIStatusBarStyle.default
    private var imageRequest: DataRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webContentView = R.nib.webContentView(owner: self)!
        contentView.insertSubview(webContentView, belowSubview: pageControlView)
        webContentView.snp.makeEdgesEqualToSuperview()
        titleStackView.snp.makeConstraints { make in
            make.trailing.equalTo(pageControlView.snp.leading).offset(-20)
        }
        
        let webView = WKWebView(frame: webViewWrapperView.bounds, configuration: webViewConfiguration)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webViewWrapperView.addSubview(webView)
        webView.snp.makeEdgesEqualToSuperview()
        webView.scrollView.panGestureRecognizer.require(toFail: edgePanGestureRecognizer)
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView
        
        let extractImageRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(extractImage(_:)))
        extractImageRecognizer.delegate = self
        webContentView.addGestureRecognizer(extractImageRecognizer)
        
        updateBackground(pageThemeColor: .background)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        imageRequest?.cancel()
    }
    
    override func popupDidDismissAsChild() {
        NotificationCenter.default.post(name: Self.didDismissNotification, object: self)
    }
    
    func updateBackground(pageThemeColor: UIColor) {
        statusBarBackgroundView.backgroundColor = pageThemeColor
        titleWrapperView.backgroundColor = pageThemeColor
        webView.backgroundColor = pageThemeColor
        
        let themeColorIsDark = pageThemeColor.w3cLightness < 0.5
        titleLabel.textColor = themeColorIsDark ? .white : textDarkColor
        pageControlView.style = themeColorIsDark ? .dark : .light
        
        if #available(iOS 13.0, *) {
            statusBarStyle = themeColorIsDark ? .lightContent : .darkContent
        } else {
            statusBarStyle = themeColorIsDark ? .lightContent : .default
        }
        setNeedsStatusBarAppearanceUpdate()
    }
    
    @objc private func extractImage(_ recognizer: UILongPressGestureRecognizer) {
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
            self.imageRequest = AF.request(urlString).responseData(completionHandler: { [weak self] (response) in
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
                        return
                    }
                    if UrlWindow.checkPayUrl(url: string) {
                        return
                    }
                    RecognizeWindow.instance().presentWindow(text: string)
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
        return true
    }
    
}
