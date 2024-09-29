import UIKit
import MixinServices

final class MarketAlertTokenCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func marketAlertTokenCell(
            _ cell: MarketAlertTokenCell,
            wantsToPerform action: MarketAlert.Action,
            to alert: MarketAlert
        )
        func marketAlertTokenCell(
            _ cell: MarketAlertTokenCell,
            wantsToEdit alert: MarketAlert,
            coin: MarketAlertCoin
        )
    }
    
    @IBOutlet weak var expandedContentView: UIView!
    @IBOutlet weak var collapsedContentView: UIView!
    @IBOutlet weak var iconImageView: PlainTokenIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var alertsStackView: UIStackView!
    
    var viewModel: MarketAlertViewModel? {
        didSet {
            if let viewModel {
                load(viewModel: viewModel)
            }
        }
    }
    
    weak var delegate: Delegate?
    
    private var alertViews: [MarketAlertItemView] = []
    
    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        if let viewModel, viewModel.isExpanded {
            expandedContentView.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: horizontalFittingPriority,
                verticalFittingPriority: verticalFittingPriority
            )
        } else {
            collapsedContentView.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: horizontalFittingPriority,
                verticalFittingPriority: verticalFittingPriority
            )
        }
    }
    
    private func load(viewModel: MarketAlertViewModel) {
        iconImageView.setIcon(tokenIconURL: viewModel.iconURL)
        titleLabel.text = viewModel.coin.name
        subtitleLabel.text = viewModel.description
        let numberOfButtonsToBeAdded = viewModel.alerts.count - alertViews.count
        if numberOfButtonsToBeAdded > 0 {
            for _ in 0..<numberOfButtonsToBeAdded {
                let view = R.nib.marketAlertItemView(withOwner: nil)!
                alertsStackView.addArrangedSubview(view)
                alertViews.append(view)
            }
        } else if numberOfButtonsToBeAdded < 0 {
            for button in alertsStackView.arrangedSubviews.suffix(-numberOfButtonsToBeAdded) {
                button.removeFromSuperview()
            }
            alertViews.removeLast(-numberOfButtonsToBeAdded)
        }
        for (i, viewModel) in viewModel.alerts.enumerated() {
            let cell = alertViews[i]
            cell.load(viewModel: viewModel)
            cell.actionButton.tag = i
            cell.actionButton.menu = UIMenu(children: alertActions(alert: viewModel.alert))
        }
    }
    
    private func alertActions(alert: MarketAlert) -> [UIAction] {
        let statusAction = switch alert.status {
        case .running:
            UIAction(
                title: R.string.localizable.pause(),
                image: R.image.action_pause()
            ) { [weak self] _ in
                guard let self else {
                    return
                }
                self.delegate?.marketAlertTokenCell(self, wantsToPerform: .pause, to: alert)
            }
        case .paused:
            UIAction(
                title: R.string.localizable.resume(),
                image: R.image.action_resume()
            ) { [weak self] _ in
                guard let self else {
                    return
                }
                self.delegate?.marketAlertTokenCell(self, wantsToPerform: .resume, to: alert)
            }
        }
        
        var actions: [UIAction] = [statusAction]
        if let coin = viewModel?.coin {
            actions.append(UIAction(
                title: R.string.localizable.edit(),
                image: R.image.action_edit()
            ) { [weak self] _ in
                guard let self else {
                    return
                }
                if let coin = viewModel?.coin {
                    
                }
                self.delegate?.marketAlertTokenCell(self, wantsToEdit: alert, coin: coin)
            })
        }
        actions.append(UIAction(
            title: R.string.localizable.delete(),
            image: R.image.conversation.ic_action_delete(),
            attributes: .destructive
        ) { [weak self] _ in
            guard let self else {
                return
            }
            self.delegate?.marketAlertTokenCell(self, wantsToPerform: .delete, to: alert)
        })
        
        return actions
    }
    
}
