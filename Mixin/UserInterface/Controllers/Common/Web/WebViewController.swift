import UIKit
import WebKit
import Alamofire
import MixinServices

class WebViewController: UIViewController {
    
    static let didDismissNotification = Notification.Name("one.mixin.messenger.WebViewController.didDismiss")
    
    @IBOutlet weak var pageControlView: PageControlView!
    
    @IBOutlet weak var statusBarBackgroundView: UIView!
    @IBOutlet weak var titleWrapperView: UIView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var webViewWrapperView: UIView!
    
    @IBOutlet weak var showPageTitleConstraint: NSLayoutConstraint!
    
    weak var webView: WKWebView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        statusBarStyle
    }
    
    var webViewConfiguration: WKWebViewConfiguration {
        WKWebViewConfiguration()
    }
    
    private var statusBarStyle: UIStatusBarStyle = .default
    private var imageRequest: DataRequest?
    
    init() {
        let nib = R.nib.webView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pageControlView.moreButton.addTarget(self, action: #selector(moreAction(_:)), for: .touchUpInside)
        pageControlView.dismissButton.addTarget(self, action: #selector(dismissAction(_:)), for: .touchUpInside)
        reloadWebView()
        let extractImageRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(extractImage(_:))
        )
        extractImageRecognizer.delegate = self
        webViewWrapperView.addGestureRecognizer(extractImageRecognizer)
        updateBackground(pageThemeColor: .background, measureDarknessWithUserInterfaceStyle: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        imageRequest?.cancel()
    }
    
    @objc func dismissAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func moreAction(_ sender: Any) {
        
    }
    
    func reloadWebView() {
        let url: URL?
        if let webView = self.webView {
            url = webView.url
            webView.removeFromSuperview()
        } else {
            url = nil
        }
        let webView = WKWebView(frame: webViewWrapperView.bounds, configuration: webViewConfiguration)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webViewWrapperView.addSubview(webView)
        webView.snp.makeEdgesEqualToSuperview()
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView
        if let url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func updateBackground(pageThemeColor: UIColor, measureDarknessWithUserInterfaceStyle: Bool) {
        statusBarBackgroundView.backgroundColor = pageThemeColor
        titleWrapperView.backgroundColor = pageThemeColor
        webView.backgroundColor = pageThemeColor
        
        let isThemeColorDark: Bool
        if measureDarknessWithUserInterfaceStyle {
            isThemeColorDark = UserInterfaceStyle.current == .dark
        } else {
            isThemeColorDark = pageThemeColor.w3cLightness < 0.5
        }
        
        titleLabel.textColor = isThemeColorDark ? .white : R.color.text()!.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        )
        pageControlView.style = isThemeColorDark ? .dark : .light
        statusBarStyle = isThemeColorDark ? .lightContent : .darkContent
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
        controller.addAction(
            UIAlertAction(
                title: R.string.localizable.save_to_camera_roll(),
                style: .default,
                handler: { [weak self] (_) in
                    PhotoLibrary.saveImage(source: .image(image)) { alert in
                        self?.present(alert, animated: true)
                    }
                }
            )
        )
        if let string = QRCodeDetector.detectString(image: image) {
            controller.addAction(
                UIAlertAction(
                    title: R.string.localizable.scan_qr_code(),
                    style: .default,
                    handler: { (_) in
                        UrlWindow.checkQrCodeDetection(string: string, clearNavigationStack: false)
                    }
                )
            )
        }
        controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        self.present(controller, animated: true, completion: nil)
    }
    
}

extension WebViewController: NavigationBarStyling {
    
    var navigationBarStyle: NavigationBarStyle {
        .hide
    }
    
}

extension WebViewController: PopupNavigationAnimating {
    
    var interactivePopOut: Bool {
        true
    }
    
}

extension WebViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}
