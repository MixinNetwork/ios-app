import UIKit
import MixinServices

final class ShareDepositLinkViewController: ShareViewAsPictureViewController<ShareObiSurroundedView<DepositLinkView>> {
    
    private let link: DepositLink
    
    private weak var linkView: DepositLinkView!
    
    init(link: DepositLink) {
        self.link = link
        let linkView = DepositLinkView()
        linkView.adjustsFontForContentSizeCategory = false
        linkView.size = .medium
        linkView.load(link: link)
        let contentView = switch link.chain {
        case .mixin:
            ShareObiSurroundedView<DepositLinkView>(contentView: linkView, spacing: .normal)
        case .native:
            ShareObiSurroundedView<DepositLinkView>(contentView: linkView, spacing: .compact)
        }
        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: 295, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        self.linkView = linkView
        super.init(contentView: contentView, size: size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.backgroundColor = R.color.background()
        actionButtonBackgroundView.effect = nil
        actionButtonTrayView.backgroundColor = R.color.background()
    }
    
    override func share(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let image = makeImage()
        let title = switch link.chain {
        case .mixin:
            R.string.localizable.receive_money()
        case .native:
            linkView.titleLabel.text
        }
        let item = QRCodeActivityItem(image: image, title: title)
        let activity = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    override func copyLink(_ sender: Any) {
        UIPasteboard.general.string = link.textValue
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        close(sender)
    }
    
    override func savePhoto(_ sender: Any) {
        let image = makeImage()
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
}
