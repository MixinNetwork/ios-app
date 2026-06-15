#if DEBUG
import UIKit
import WebKit

enum OpenInBrowserBridgeUITestHarness {
    static let launchArgument = "--open-in-browser-bridge-ui-test"
    static let urlEnvironmentKey = "OPEN_IN_BROWSER_BRIDGE_URL"
    static let resultIdentifier = "openInBrowserBridgeResult"

    static func installIfNeeded(in window: UIWindow) -> Bool {
        guard CommandLine.arguments.contains(launchArgument) else {
            return false
        }
        let urlString = ProcessInfo.processInfo.environment[urlEnvironmentKey] ?? "https://mixin.one/pay"
        window.rootViewController = OpenInBrowserBridgeUITestViewController(urlString: urlString)
        window.makeKeyAndVisible()
        return true
    }
}

private final class OpenInBrowserBridgeUITestViewController: UIViewController {
    private let urlString: String
    private let resultLabel = UILabel()
    private lazy var messageHandler = WebViewMessageHandler(delegate: self)
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        for name in WebViewMessageHandler.Name.allCases.map(\.rawValue) {
            configuration.userContentController.add(messageHandler, name: name)
        }
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    init(urlString: String) {
        self.urlString = urlString
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let controller = webView.configuration.userContentController
        WebViewMessageHandler.Name.allCases.map(\.rawValue)
            .forEach(controller.removeScriptMessageHandler(forName:))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        resultLabel.accessibilityIdentifier = OpenInBrowserBridgeUITestHarness.resultIdentifier
        resultLabel.text = "waiting"
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultLabel)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.alpha = 0.01
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resultLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.widthAnchor.constraint(equalToConstant: 1),
            webView.heightAnchor.constraint(equalToConstant: 1),
        ])

        webView.loadHTMLString(html, baseURL: URL(string: "https://mixin.one")!)
    }

    private var html: String {
        let payload = try! JSONEncoder().encode(urlString)
        let encodedURL = String(data: payload, encoding: .utf8)!
        return """
        <!doctype html>
        <html>
        <body>
        <script>
        window.addEventListener('load', function() {
          window.webkit.messageHandlers.openInBrowser.postMessage(\(encodedURL));
        });
        </script>
        </body>
        </html>
        """
    }
}

extension OpenInBrowserBridgeUITestViewController: WebViewMessageHandler.Delegate {
    func webViewMessageHander(_ handler: WebViewMessageHandler, didReceiveMessage message: WebViewMessageHandler.Message) {
        guard case .openInBrowser(let url) = message else {
            return
        }
        resultLabel.text = url.absoluteString
    }

    func webViewMessageHanderGetCurrentURL(_ handler: WebViewMessageHandler) -> URL? {
        URL(string: "https://mixin.one")
    }
}
#endif
