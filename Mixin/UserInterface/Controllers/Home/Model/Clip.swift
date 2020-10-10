import UIKit
import MixinServices

class Clip {
    
    let app: App?
    let title: String
    let url: URL
    let controller: MixinWebViewController
    var thumbnail: UIImage?
    
    init(app: App?, url: URL, controller: MixinWebViewController) {
        self.app = app
        if let app = app {
            self.title = app.name
        } else {
            self.title = controller.titleLabel.text ?? ""
        }
        self.url = url
        self.thumbnail = nil
        self.controller = controller
    }
    
}
