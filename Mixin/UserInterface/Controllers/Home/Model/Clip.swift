import UIKit
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
            if let controller = _controller {
                return controller
            } else if let app = app {
                return MixinWebViewController.instance(with: .init(conversationId: "", app: app))
            } else {
                return MixinWebViewController.instance(with: .init(conversationId: "", initialUrl: url))
            }
        }()
        _controller = controller
        return controller
    }
    
    private var _controller: MixinWebViewController?
    
    init(app: App?, url: URL, controller: MixinWebViewController) {
        self.app = app
        if let app = app {
            self.title = app.name
        } else {
            self.title = controller.titleLabel.text ?? ""
        }
        self.url = url
        self.thumbnail = nil
        self._controller = controller
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try container.decode(App.self, forKey: .app)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(URL.self, forKey: .url)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(app, forKey: .app)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
    }
    
}
