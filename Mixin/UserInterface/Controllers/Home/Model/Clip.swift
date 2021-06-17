import UIKit
import WebKit
import MixinServices

final class Clip: Codable {
    
    enum CodingKeys: String, CodingKey {
        case id, app, title, url
        case isShareable = "shareable"
        case conversationId = "conversation_id"
    }
    
    static let propertiesDidUpdateNotification = Notification.Name("one.mixin.messenger.Clip.propertiesDidUpdate")
    
    private static let thumbnailProcessingQueue = DispatchQueue(label: "one.mixin.messenger.Clip.ThumbnailProcessing")
    
    private static var thumbnailCachesURL: URL? {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls.first?.appendingPathComponent("Clips")
    }
    
    let id: UUID
    let conversationId: String
    let app: App?
    let isShareable: Bool?
    
    private(set) var title: String
    private(set) var url: URL
    
    private var _thumbnail: UIImage?
    
    var thumbnail: UIImage? {
        get {
            _thumbnail
        }
        set {
            _thumbnail = newValue
            Self.thumbnailProcessingQueue.async {
                self.updateCache(for: newValue)
            }
        }
    }
    
    var controller: MixinWebViewController {
        let controller: MixinWebViewController = {
            if let controller = controllerIfLoaded {
                return controller
            } else {
                let context: MixinWebViewController.Context
                if let app = app {
                    context = .init(conversationId: conversationId, app: app, shareable: isShareable)
                } else {
                    context = .init(conversationId: conversationId, initialUrl: url, shareable: isShareable)
                }
                return MixinWebViewController.instance(with: context)
            }
        }()
        controller.associatedClip = self
        controllerIfLoaded = controller
        return controller
    }
    
    private(set) var controllerIfLoaded: MixinWebViewController?
    
    private var thumbnailCacheURL: URL? {
        Self.thumbnailCachesURL?.appendingPathComponent(id.uuidString)
    }
    
    init(app: App?, url: URL, controller: MixinWebViewController) {
        self.id = UUID()
        self.conversationId = controller.context.conversationId
        self.app = app
        self.isShareable = controller.context.isShareable
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
        self.id = try container.decode(UUID.self, forKey: .id)
        self.conversationId = (try? container.decodeIfPresent(String.self, forKey: .conversationId)) ?? ""
        self.app = try container.decodeIfPresent(App.self, forKey: .app)
        self.isShareable = (try? container.decodeIfPresent(Bool.self, forKey: .isShareable)) ?? true
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(URL.self, forKey: .url)
        addObservers()
        loadThumbnailFromCache()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let url = self.thumbnailCacheURL {
            Self.thumbnailProcessingQueue.async {
                try? FileManager.default.removeItem(at: url)
            }
        }
        if let controller = controllerIfLoaded, controller.viewIfLoaded == nil || controller.view.window == nil {
            controller.removeAllMessageHandlers()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(conversationId, forKey: .conversationId)
        try container.encode(app, forKey: .app)
        try container.encode(isShareable, forKey: .isShareable)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
    }
    
}

extension Clip: Equatable {
    
    static func == (lhs: Clip, rhs: Clip) -> Bool {
        lhs.id == rhs.id
    }
    
}

extension Clip {
    
    @objc private func removeCachedController() {
        guard let controller = controllerIfLoaded else {
            return
        }
        let isControllerInvisible: Bool
        if let view = controller.viewIfLoaded {
            isControllerInvisible = view.window == nil
        } else {
            isControllerInvisible = true
        }
        if isControllerInvisible {
            controller.removeAllMessageHandlers()
            controllerIfLoaded = nil
        }
    }
    
    @objc private func updateProperties(_ notification: Notification) {
        guard let controller = notification.object as? WebViewController, controller == controllerIfLoaded else {
            return
        }
        
        let config = WKSnapshotConfiguration()
        config.rect = controller.webView.frame
        config.snapshotWidth = NSNumber(value: Int(controller.webView.frame.width))
        controller.webView.takeSnapshot(with: config) { [weak self] (image, error) in
            self?.thumbnail = image
        }
        
        updateURLAndTitle()
    }
    
    @objc private func applicationWillTerminate() {
        if controllerIfLoaded?.parent != nil {
            updateURLAndTitle()
        }
    }
    
}

extension Clip {
    
    private func addObservers() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(removeCachedController),
                           name: UIApplication.didReceiveMemoryWarningNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(updateProperties(_:)),
                           name: WebViewController.didDismissNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(applicationWillTerminate),
                           name: UIApplication.willTerminateNotification,
                           object: nil)
    }
    
    private func updateURLAndTitle() {
        var hasPropertyChange = false
        if let url = controller.webView.url, self.url != url {
            self.url = url
            hasPropertyChange = true
        }
        if app == nil {
            self.title = controller.webView.title ?? ""
            hasPropertyChange = true
        }
        if hasPropertyChange {
            NotificationCenter.default.post(name: Self.propertiesDidUpdateNotification, object: self)
        }
    }
    
    private func updateCache(for thumbnail: UIImage?) {
        let fileManager = FileManager.default
        guard let thumbnailCachesURL = Self.thumbnailCachesURL else {
            return
        }
        
        var isDirectory = ObjCBool(false)
        var isExist = fileManager.fileExists(atPath: thumbnailCachesURL.path, isDirectory: &isDirectory)
        if isExist && !isDirectory.boolValue {
            try? fileManager.removeItem(at: thumbnailCachesURL)
        } else if !isExist {
            try? fileManager.createDirectory(at: thumbnailCachesURL,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
        }
        isExist = fileManager.fileExists(atPath: thumbnailCachesURL.path, isDirectory: &isDirectory)
        guard isExist && isDirectory.boolValue else {
            return
        }
        
        guard let url = self.thumbnailCacheURL else {
            return
        }
        if let thumbnail = thumbnail {
            let data = thumbnail.jpegData(compressionQuality: JPEGCompressionQuality.low)
            try? data?.write(to: url)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }
    
    private func loadThumbnailFromCache() {
        guard let url = thumbnailCacheURL else {
            return
        }
        Self.thumbnailProcessingQueue.async { [weak self] in
            guard let data = try? Data(contentsOf: url) else {
                return
            }
            guard let image = UIImage(data: data) else {
                return
            }
            DispatchQueue.main.async {
                if self?.thumbnail == nil {
                    self?._thumbnail = image
                }
            }
        }
    }
    
}
