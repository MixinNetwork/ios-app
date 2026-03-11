import UIKit

final class SharePerpetualPositionViewController: ShareViewAsPictureViewController {
    
    private let viewModel: PerpetualPositionViewModel
    
    private weak var positionView: SharePerpetualPositionView!
    
    init(viewModel: PerpetualPositionViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func loadContentView() {
        let positionView = R.nib.sharePerpetualPositionView(withOwner: nil)
        self.positionView = positionView
        self.contentView = positionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        positionView.load(viewModel: viewModel)
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
        UIPasteboard.general.string = "https://mixin.one/trade?type=perps&product=\(viewModel.marketID)"
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        close(sender)
    }
    
    override func savePhoto(_ sender: Any) {
        let image = makeImage()
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
    private func makeImage() -> UIImage {
        let canvas = contentView.bounds
        let renderer = UIGraphicsImageRenderer(bounds: canvas)
        contentView.layer.cornerRadius = 0
        let image = renderer.image { context in
            contentView.drawHierarchy(in: canvas, afterScreenUpdates: true)
        }
        contentView.layer.cornerRadius = contentViewCornerRadius
        return image
    }
    
}
