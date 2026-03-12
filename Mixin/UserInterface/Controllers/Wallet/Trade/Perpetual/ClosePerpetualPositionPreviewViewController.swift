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
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_closing_position()
        tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixin)
        
        var rows: [Row] = []
        if let name = viewModel.displaySymbol {
            rows.append(.perpsProduct(iconURL: viewModel.iconURL, name: name))
        }
        if let assetID = viewModel.settleAssetID,
           let payAmount = viewModel.openPayAmount,
           let pnlPercentage = viewModel.pnlPercentage,
           let token = TokenDAO.shared.tokenItem(assetID: assetID)
        {
            let count = CurrencyFormatter.localizedString(
                from: payAmount * (1 + pnlPercentage),
                format: .precision,
                sign: .always,
                symbol: .custom(token.symbol)
            )
            let pnl = NSMutableAttributedString(
                string: R.string.localizable.pnl() + ": ",
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: R.color.text_tertiary()!
                ]
            )
            let pnlValue = CurrencyFormatter.localizedString(
                from: payAmount * pnlPercentage,
                format: .precision,
                sign: .always,
                symbol: .custom(token.symbol)
            ) + "(" + PercentageFormatter.string(
                from: pnlPercentage,
                format: .pretty,
                sign: .always,
                options: .keepOneFractionDigitForZero
            ) + ")"
            pnl.append(NSAttributedString(
                string: pnlValue,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: viewModel.pnlColor.uiColor
                ]
            ))
            rows.append(.estimatedReceive(token: token, count: count, pnl: pnl))
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
            title: R.string.localizable.closing_position(),
            subtitle: R.string.localizable.signature_request_from(.mixin)
        )
        replaceTrayView(with: nil, animation: .vertical)
        let positionID = viewModel.positionID
        let walletID = viewModel.wallet.tradeOrderWalletID
        Task {
            do {
                try await AccountAPI.verify(pin: pin)
                try await RouteAPI.closePerpsOrder(positionID: positionID)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(
                        title: R.string.localizable.position_closed(),
                        subtitle: R.string.localizable.position_closed_description()
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
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    let history = SyncPerpsPositionHistoryJob(walletID: walletID)
                    ConcurrentJobQueue.shared.addJob(job: history)
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
                    let title = R.string.localizable.position_closing_failed()
                    layoutTableHeaderView(
                        title: title,
                        subtitle: errorDescription,
                        style: .destructive
                    )
                    tableView.setContentOffset(.zero, animated: true)
                    switch error {
                    case MixinAPIResponseError.malformedPin, MixinAPIResponseError.incorrectPin, TIPNode.Error.response(.incorrectPIN), TIPNode.Error.response(.internalServer):
                        loadDoubleButtonTrayView(
                            leftTitle: R.string.localizable.cancel(),
                            leftAction: #selector(close(_:)),
                            rightTitle: R.string.localizable.retry(),
                            rightAction: #selector(confirm(_:)),
                            animation: .vertical
                        )
                    default:
                        loadSingleButtonTrayView(
                            title: R.string.localizable.got_it(),
                            action: #selector(close(_:))
                        )
                    }
                }
            }
        }
    }
    
}
