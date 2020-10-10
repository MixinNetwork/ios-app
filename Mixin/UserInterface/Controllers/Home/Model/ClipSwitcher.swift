import UIKit
import WebKit

class ClipSwitcher {
    
    private(set) var clips: [Clip] = []
    
    private var minimizedController: MinimizedClipSwitcherViewController? {
        let container = UIApplication.homeContainerViewController
        return container?.minimizedClipSwitcherViewController
    }
    
    func insert(_ controller: MixinWebViewController) {
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
    }
    
    func removeClip(at index: Int) {
        minimizedController?.clips.remove(at: index)
        clips.remove(at: index)
    }
    
    func removeAll() {
        minimizedController?.clips = []
        clips = []
    }
    
    @objc func showFullscreenSwitcher() {
        let switcher = R.storyboard.home.clip_switcher()!
        switcher.clips = clips
        switcher.show()
    }
    
}
