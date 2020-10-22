import UIKit
import WebKit
import MixinServices

final class Clip: Codable {
    
    enum CodingKeys: CodingKey {
        case app, title, url
    }
    
    let app: App?
    let title: String
    let url: URL
    
    var thumbnail: UIImage?
    var controller: MixinWebViewController {
        let controller: MixinWebViewController = {
            if let controller = controllerIfLoaded {
                return controller
            } else if let app = app {
                return MixinWebViewController.instance(with: .init(conversationId: "", app: app))
            } else {
                return MixinWebViewController.instance(with: .init(conversationId: "", initialUrl: url))
            }
        }()
        controllerIfLoaded = controller
        return controller
    }
    
    private(set) var controllerIfLoaded: MixinWebViewController?
    
    init(app: App?, url: URL, controller: MixinWebViewController) {
        self.app = app
        if let app = app {
            self.title = app.name
        } else {
            self.title = controller.titleLabel.text ?? ""
        }
        self.url = url
        self.thumbnail = nil
        self.controllerIfLoaded = controller
        addObservers()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try container.decodeIfPresent(App.self, forKey: .app)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(URL.self, forKey: .url)
        addObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(app, forKey: .app)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
    }
    
    func removeCachedController() {
        controllerIfLoaded = nil
    }
    
    @objc private func updateThumbnail(_ notification: Notification) {
        guard let controller = notification.object as? WebViewController, controller == controllerIfLoaded else {
            return
        }
        let config = WKSnapshotConfiguration()
        config.rect = controller.webView.frame
        config.snapshotWidth = NSNumber(value: Int(controller.webView.frame.width))
        controller.webView.takeSnapshot(with: config) { [weak self] (image, error) in
            self?.thumbnail = image
        }
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateThumbnail(_:)), name: WebViewController.didDismissNotification, object: nil)
    }
    
}
