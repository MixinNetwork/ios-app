import UIKit
import WebKit
import MixinServices

class ClipSwitcher {
    
    static let maxNumber = 6
    
    private let encoder = JSONEncoder.default
    
    private(set) var clips: [Clip] = []
    private(set) weak var fullscreenSwitcherIfLoaded: ClipSwitcherViewController?
    
    private lazy var fullscreenSwitcher: ClipSwitcherViewController = {
        let controller = R.storyboard.home.clip_switcher()!
        self.fullscreenSwitcherIfLoaded = controller
        return controller
    }()
    
    private var minimizedController: MinimizedClipSwitcherViewController? {
        let container = UIApplication.homeContainerViewController
        return container?.minimizedClipSwitcherViewController
    }
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateSerializedClip(_:)),
                                               name: Clip.propertiesDidUpdateNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadClipsFromPreviousSession() {
        clips = AppGroupUserDefaults.User.clips.compactMap { (data) -> Clip? in
            try? JSONDecoder.default.decode(Clip.self, from: data)
        }
        if !clips.isEmpty, let controller = minimizedController {
            controller.replaceClips(with: clips)
            controller.panningController.placeViewNextToLastOverlayOrTopRight()
        }
    }
    
    func appendClip(with controller: MixinWebViewController) {
        guard !clips.contains(where: { $0.controllerIfLoaded == controller }) else {
            return
        }
        let clip: Clip
        switch controller.context.style {
        case let .app(app, _):
            clip = Clip(app: app,
                        url: controller.webView.url ?? URL(string: app.homeUri) ?? .blank,
                        controller: controller)
        case .webPage:
            clip = Clip(app: nil,
                        url: controller.webView.url ?? .blank,
                        controller: controller)
        }
        minimizedController?.appendClip(clip, animated: true)
        clips.append(clip)
        
        let config = WKSnapshotConfiguration()
        config.rect = controller.webView.frame
        config.snapshotWidth = NSNumber(value: Int(controller.webView.frame.width))
        controller.webView.takeSnapshot(with: config) { (image, error) in
            clip.thumbnail = image
        }
        
        if clips.count == AppGroupUserDefaults.User.clips.count + 1, let encoded = try? encoder.encode(clip) {
            AppGroupUserDefaults.User.clips.append(encoded)
        } else {
            updateAllSerializedClips()
        }
    }
    
    func removeClip(at index: Int) {
        minimizedController?.removeClip(at: index, animated: true)
        clips.remove(at: index)
        if index < AppGroupUserDefaults.User.clips.count {
            AppGroupUserDefaults.User.clips.remove(at: index)
        } else {
            updateAllSerializedClips()
        }
        
        // Remove the clip immediately will release the unretained clip ASAP,
        // as well as the webview associated with it, or the clip will be released
        // on next time of full screen switcher's showing
        fullscreenSwitcherIfLoaded?.clips = clips
    }
    
    func replaceClips(with clips: [Clip]) {
        minimizedController?.replaceClips(with: clips)
        self.clips = clips
        updateAllSerializedClips()
        fullscreenSwitcherIfLoaded?.clips = clips
    }
    
    func hideFullscreenSwitcher() {
        fullscreenSwitcher.hide()
    }
    
    @objc func showFullscreenSwitcher() {
        fullscreenSwitcher.clips = clips
        fullscreenSwitcher.show()
    }
    
    @objc private func updateSerializedClip(_ notification: Notification) {
        guard let clip = notification.object as? Clip else {
            return
        }
        if let index = clips.firstIndex(where: { $0 == clip }), index < AppGroupUserDefaults.User.clips.count, let encoded = try? encoder.encode(clip) {
            AppGroupUserDefaults.User.clips[index] = encoded
        } else {
            updateAllSerializedClips()
        }
    }
    
    private func updateAllSerializedClips() {
        AppGroupUserDefaults.User.clips = clips.compactMap { (clip) -> Data? in
            try? JSONEncoder.default.encode(clip)
        }
    }
    
}
