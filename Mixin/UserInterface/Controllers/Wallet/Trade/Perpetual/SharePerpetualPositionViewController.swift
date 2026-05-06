import UIKit
import MixinServices

final class SharePerpetualPositionViewController: ShareViewAsPictureViewController<SharePerpetualPositionView> {
    
    private let viewModel: PerpetualPositionViewModel
    
    private weak var positionView: SharePerpetualPositionView!
    
    init(viewModel: PerpetualPositionViewModel, latestPrice: Decimal?) {
        self.viewModel = viewModel
        let contentView = R.nib.sharePerpetualPositionView(withOwner: nil)!
        contentView.load(viewModel: viewModel, latestPrice: latestPrice)
        contentView.obiView.load(content: .installMixin(gradient: false))
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
        RewardAPI.referral { [weak obiView=contentView.obiView] result in
            switch result {
            case let .success(referral):
                let defaultCode = referral.codes.first { code in
                    code.isDefault
                }
                let ratio = Decimal(
                    string: referral.tradingCommissionRatio,
                    locale: .enUSPOSIX
                )
                if let code = defaultCode?.code, let ratio {
                    obiView?.load(content: .referral(code: code, rebate: ratio))
                }
            case .failure:
                break
            }
        }
    }
    
    override func share(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let image = makeImage()
        let title = viewModel.directionWithSymbol
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
        UIPasteboard.general.string = URL.shortMixinMessenger.absoluteString
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
