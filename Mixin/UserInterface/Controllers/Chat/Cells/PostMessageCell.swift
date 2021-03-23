import UIKit
import WebKit

class PostMessageCell: TextMessageCell {
    
    let webView = WKWebView()
    let expandImageView = UIImageView(image: R.image.conversation.ic_message_expand())
    let trailingInfoBackgroundView = TrailingInfoBackgroundView()
    
    override func prepare() {
        messageContentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        messageContentView.addSubview(webView)
        messageContentView.addSubview(expandImageView)
        forwarderImageView.alpha = 0.9
        encryptedImageView.alpha = 0.9
        statusImageView.alpha = 0.9
        contentLabel.isHidden = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        let expandImageMargin: CGFloat
        if viewModel.style.contains(.received) {
            expandImageMargin = 9
        } else {
            expandImageMargin = 16
        }
        let origin = CGPoint(x: viewModel.backgroundImageFrame.maxX - expandImageView.frame.width - expandImageMargin,
                             y: viewModel.backgroundImageFrame.origin.y + 8)
        expandImageView.frame.origin = origin
        if let viewModel = viewModel as? PostMessageViewModel {
            webView.frame = viewModel.contentLabelFrame
            webView.loadHTMLString(viewModel.html, baseURL: Bundle.main.bundleURL)
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
        }
    }
    
}
