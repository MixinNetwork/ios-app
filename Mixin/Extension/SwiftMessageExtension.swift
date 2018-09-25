import UIKit
import SwiftMessages


extension SwiftMessages {

    class func showToast(message: String, backgroundColor: UIColor, duration: Duration = .automatic) {
        let view = MessageView.viewFromNib(layout: .messageView)
        view.configureTheme(backgroundColor: backgroundColor, foregroundColor: .white)
        view.configureContent(body: message)
        view.bodyLabel?.textAlignment = .center
        view.titleLabel?.isHidden = true
        view.button?.isHidden = true
        view.iconImageView?.isHidden = true
        view.iconLabel?.isHidden = true
        view.configureDropShadow()

        var config = SwiftMessages.defaultConfig
        config.presentationStyle = .top
        config.shouldAutorotate = true
        config.interactiveHide = true
        config.presentationContext = .window(windowLevel: .statusBar + 2)
        config.duration = duration

        SwiftMessages.show(config: config, view: view)
    }

}
