import UIKit
import MixinServices

final class ClosePerpetualPositionPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    private let viewModel: PerpetualPositionViewModel
    
    init(
        viewModel: PerpetualPositionViewModel
    ) {
        self.viewModel = viewModel
        super.init(wallet: viewModel.wallet, warnings: [])
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setTokenIcon(url: viewModel.iconURL)
        tableHeaderView.titleLabel.text = "确认平仓"
        tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixin)
        
        var rows: [Row] = []
        if let product = viewModel.product {
            rows.append(.perpsProduct(iconURL: viewModel.iconURL, name: product))
        }
        rows.append(contentsOf: [
            .wallet(caption: .sender, wallet: viewModel.wallet, threshold: nil),
        ])
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(
            title: "Closing Position",
            subtitle: R.string.localizable.signature_request_from(.mixin)
        )
        replaceTrayView(with: nil, animation: .vertical)
        let positionID = viewModel.positionID
        Task {
            do {
                try await RouteAPI.closePerpsOrder(positionID: positionID)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(
                        title: "Position Closed",
                        subtitle: "Under Construction"
                    )
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                    if let navigationController = UIApplication.homeNavigationController {
                        var viewControllers = navigationController.viewControllers
                        if viewControllers.last is PerpetualPositionViewController {
                            viewControllers.removeLast()
                        }
                        if viewControllers.last is PerpetualMarketViewController {
                            viewControllers.removeLast()
                        }
                        navigationController.setViewControllers(viewControllers, animated: false)
                    }
                }
            } catch {
                let errorDescription = if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                    await PINVerificationFailureHandler.handle(error: error)
                } else {
                    error.localizedDescription
                }
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .failure)
                    let title = R.string.localizable.swap_failed()
                    layoutTableHeaderView(title: title,
                                          subtitle: errorDescription,
                                          style: .destructive)
                    tableView.setContentOffset(.zero, animated: true)
                    switch error {
                    case MixinAPIResponseError.malformedPin, MixinAPIResponseError.incorrectPin, TIPNode.Error.response(.incorrectPIN), TIPNode.Error.response(.internalServer):
                        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                 leftAction: #selector(close(_:)),
                                                 rightTitle: R.string.localizable.retry(),
                                                 rightAction: #selector(confirm(_:)),
                                                 animation: .vertical)
                    default:
                        loadSingleButtonTrayView(title: R.string.localizable.got_it(),
                                                 action: #selector(close(_:)))
                    }
                }
            }
        }
    }
    
}
