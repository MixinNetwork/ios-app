import UIKit
import WebKit
import MixinServices

class ClipSwitcher {
    
    private(set) var clips: [Clip] = []
    
    private var minimizedController: MinimizedClipSwitcherViewController? {
        let container = UIApplication.homeContainerViewController
        return container?.minimizedClipSwitcherViewController
    }
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReceiveMemoryWarningNotification(_:)),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadClipsFromPreviousSession() {
        clips = AppGroupUserDefaults.User.clips.compactMap { (data) -> Clip? in
            try? JSONDecoder.default.decode(Clip.self, from: data)
        }
        if let controller = minimizedController {
            controller.clips = clips
            controller.panningController.placeViewToTopRight()
        }
    }
    
    func insert(_ controller: MixinWebViewController) {
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
        minimizedController?.clips.append(clip)
        clips.append(clip)
        
        let config = WKSnapshotConfiguration()
        config.rect = controller.webView.frame
        config.snapshotWidth = NSNumber(value: Int(controller.webView.frame.width))
        controller.webView.takeSnapshot(with: config) { (image, error) in
            clip.thumbnail = image
        }
        
        AppGroupUserDefaults.User.clips = clips.compactMap { (clip) -> Data? in
            try? JSONEncoder.default.encode(clip)
        }
    }
    
    func removeClip(at index: Int) {
        minimizedController?.clips.remove(at: index)
        clips.remove(at: index)
        if index < AppGroupUserDefaults.User.clips.count {
            AppGroupUserDefaults.User.clips.remove(at: index)
        }
    }
    
    func removeAll() {
        minimizedController?.clips = []
        clips = []
        AppGroupUserDefaults.User.clips = []
    }
    
    @objc func showFullscreenSwitcher() {
        let switcher = R.storyboard.home.clip_switcher()!
        switcher.clips = clips
        switcher.show()
    }
    
    @objc func didReceiveMemoryWarningNotification(_ notification: Notification) {
        if clips.count > 6 {
            for clip in clips[0..<(clips.count - 6)] {
                clip.removeCachedController()
            }
        } else {
            for clip in clips {
                clip.removeCachedController()
            }
        }
    }
    
}
