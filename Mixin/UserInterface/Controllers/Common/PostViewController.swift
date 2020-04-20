import UIKit
import MixinServices
import Maaku
import TexturedMaaku

class PostViewController: UIViewController {
    
    let contentView = UIView()
    let controlView = PageControlView()
    let message: MessageItem
    
    init(message: MessageItem) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func presentInstance(with message: MessageItem, asChildOf parent: UIViewController) {
        let vc = PostViewController(message: message)
        vc.view.frame = parent.view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addChild(vc)
        parent.view.addSubview(vc.view)
        vc.didMove(toParent: parent)
        
        vc.view.center.y = parent.view.bounds.height * 3 / 2
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            vc.view.center.y = parent.view.bounds.height / 2
        }
        
        AppDelegate.current.mainWindow.endEditing(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        contentView.backgroundColor = .background
        contentView.clipsToBounds = true
        view.addSubview(contentView)
        contentView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }
        let recognizer = WebViewScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgePanAction(_:)))
        recognizer.edges = [.left]
        contentView.addGestureRecognizer(recognizer)
        
        if let document = try? Document(text: message.content) {
            let style = PostDocumentStyle()
            let controller = PostDocumentViewController(document: document, style: style)
            addChild(controller)
            contentView.addSubview(controller.view)
            controller.view.snp.makeEdgesEqualToSuperview()
            controller.didMove(toParent: self)
        }
        
        controlView.style = .current
        controlView.moreButton.addTarget(self, action: #selector(showMoreMenu), for: .touchUpInside)
        controlView.dismissButton.addTarget(self, action: #selector(dismissPost), for: .touchUpInside)
        contentView.addSubview(controlView)
        controlView.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview().offset(-10)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        controlView.style = .current
    }
    
    @objc func screenEdgePanAction(_ recognizer: WebViewScreenEdgePanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if view.safeAreaInsets.top > 20 {
                contentView.layer.cornerRadius = 39
            } else {
                contentView.layer.cornerRadius = 20
            }
        case .changed:
            let scale = 1 - 0.2 * recognizer.fractionComplete
            contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        case .ended:
            dismissPost()
        case .cancelled:
            UIView.animate(withDuration: 0.25, animations: {
                self.contentView.transform = .identity
            }, completion: { _ in
                self.contentView.layer.cornerRadius = 0
            })
        default:
            break
        }
    }
    
    @objc func showMoreMenu() {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: R.string.localizable.chat_message_menu_forward(), style: .default, handler: { (_) in
            let vc = MessageReceiverViewController.instance(content: .messages([self.message]))
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    @objc func dismissPost() {
        if let parent = parent {
            parent.setNeedsStatusBarAppearanceUpdate()
            UIView.animate(withDuration: 0.5, animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.center.y = parent.view.bounds.height * 3 / 2
            }) { (_) in
                self.willMove(toParent: nil)
                self.view.removeFromSuperview()
                self.removeFromParent()
            }
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
}

extension PostViewController {
    
    private class PostDocumentViewController: DocumentViewController {
        
        override func linkTapped(_ url: URL) {
            if UrlWindow.checkUrl(url: url, fromWeb: true) {
                return
            }
            guard let parent = parent else {
                return
            }
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url), asChildOf: parent)
        }
        
        override func contentSizeCategoryChange(_ contentSizeCategory: UIContentSizeCategory) {
            
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            documentStyle = PostDocumentStyle()
        }
        
    }
    
    private struct PostColors: DocumentColors {
        
        var background: UIColor = .background
        var blockQuoteLine: UIColor = .accessoryText
        var circleHeaderBackground: UIColor = .secondaryBackground
        var circleHeaderForeground: UIColor = .secondaryBackground
        var codeBlockBackground: UIColor = .secondaryBackground
        var horizontalRule: UIColor = .accessoryText
        
    }
    
    private struct PostColorStyle: ColorStyle {
        
        var current: Color = .text
        var h1: Color = .text
        var h2: Color = .text
        var h3: Color = .text
        var h4: Color = .text
        var h5: Color = .text
        var h6: Color = .text
        var inlineCodeForeground: Color = .text
        var inlineCodeBackground: Color = .secondaryBackground
        var link: Color = .theme
        var linkUnderline: Color = .clear
        var paragraph: Color = .text
        
    }
    
    private struct PostDocumentInsets: DocumentInsets {
        
        var document = UIEdgeInsets.zero
        var blockQuote = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        var codeBlock = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        var footNoteDefinition = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        var heading = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        var horizontalRule = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        var list = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        var paragraph = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        var table = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        
    }
    
    private struct PostStyle: Style {
        
        var colors: ColorStyle = PostColorStyle()
        var fonts: FontStyle = DefaultFontStyle()
        var hasStrikethrough: Bool = false
        var softbreakSeparator: String = "\n"
        
    }
    
    private struct PostDocumentValues: DocumentValues {
        
        var blockQuoteLineWidth: CGFloat = 3.0
        var horizontalRuleHeight: CGFloat = 1
        var circleHeaderRadius: CGFloat = 15.5
        var circleHeaderFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .heavy)
        var unorderedListSymbol: String = "•"
        var circleHeadersEnabled: Bool = true
        var codeHighlighterTheme: String = UserInterfaceStyle.current == .dark ? "a11y-dark" : "a11y-light"
        var codeFont: UIFont = UIFont.preferredFont(forTextStyle: .body)
        
    }
    
    private struct PostDocumentStyle: DocumentStyle {
        
        var insets: DocumentInsets = PostDocumentInsets()
        var colors: DocumentColors = PostColors()
        var values: DocumentValues = PostDocumentValues()
        var maakuStyle: Style = PostStyle()
        
    }
    
}
