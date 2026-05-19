import UIKit
import MixinServices

final class SharePerpetualPositionViewController: ShareViewAsPictureViewController<SharePerpetualPositionView> {
    
    private let activityItemTitle: String
    private let link: String
    
    private weak var positionView: SharePerpetualPositionView!
    
    init(
        dataSource: SharePerpetualPositionDataSource,
        rebatingCode: Referral.RebatingCode?,
    ) {
        let contentView = R.nib.sharePerpetualPositionView(withOwner: nil)!
        contentView.load(dataSource: dataSource)
        let link = if let rebatingCode {
            contentView.obiView.load(gradient: false, content: .referral(rebatingCode))
        } else {
            contentView.obiView.load(gradient: false, content: .installMixin)
        }
        self.activityItemTitle = dataSource.title
        self.link = link
        super.init(contentView: contentView, size: CGSize(width: 295, height: 553))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        closeButton.overrideUserInterfaceStyle = .light
        actionButtonBackgroundView.effect = nil
        actionButtonTrayView.backgroundColor = R.color.background()
    }
    
    override func share(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let image = makeImage()
        let item = QRCodeActivityItem(image: image, title: activityItemTitle)
        let activity = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    override func copyLink(_ sender: Any) {
        UIPasteboard.general.string = link
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
