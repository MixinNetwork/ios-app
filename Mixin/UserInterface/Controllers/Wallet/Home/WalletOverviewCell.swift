import UIKit
import MixinServices

final class WalletOverviewCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func walletOverviewCell(_ cell: WalletOverviewCell, didSelectTokenAction action: TokenAction)
        func walletOverviewCell(_ cell: WalletOverviewCell, didSelectImportAction action: WalletOverview.ImportSecretAction)
        func walletOverviewCellDidSelectPendingDeposits(_ cell: WalletOverviewCell)
        func walletOverviewCellDidSelectPendingTransactions(_ cell: WalletOverviewCell)
        func walletOverviewCellDidSelectWatchingAddresses(_ cell: WalletOverviewCell)
    }
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueStackView: UIStackView!
    @IBOutlet weak var valueLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var btcValueLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    weak var delegate: Delegate?
    
    private weak var importSecretButton: UIButton?
    private weak var tokenActionView: TokenActionView?
    private weak var pendingDepositView: WalletPendingDepositView?
    private weak var watchingIndicatorView: WalletWatchingIndicatorView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleStackView.setCustomSpacing(0, after: valueStackView)
        titleLabel.text = R.string.localizable.total_balance()
        valueLabel.font = .condensed(size: 30)
        valueLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 5, right: 0)
        symbolLabel.text = Currency.current.code
    }
    
    func load(overview: WalletOverview?) {
        if let overview {
            valueLabel.text = overview.value
            btcValueLabel.text = overview.btcValue
        } else {
            valueLabel.text = "-"
            btcValueLabel.text = "-"
        }
    }
    
    func load(action: WalletOverview.Action?) {
        switch action {
        case .importSecret(let action):
            tokenActionView?.removeFromSuperview()
            
            let title = switch action {
            case .importPrivateKey:
                R.string.localizable.import_private_key()
            case .importMnemonics:
                R.string.localizable.import_mnemonic_phrase()
            }
            var config: UIButton.Configuration = .filled()
            config.baseForegroundColor = .white
            config.baseBackgroundColor = R.color.theme()
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14, weight: .medium)
            )
            config.attributedTitle = AttributedString(title, attributes: attributes)
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
            config.background.cornerRadius = 12
            config.background.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            
            let button: UIButton
            if let b = importSecretButton, b.superview != nil {
                button = b
                button.configuration = config
                button.removeTarget(nil, action: nil, for: .allEvents)
            } else {
                button = UIButton(configuration: config)
                actionStackView.insertArrangedSubview(button, at: 0)
                button.snp.makeConstraints { make in
                    make.width.equalToSuperview()
                }
                importSecretButton = button
            }
            switch action {
            case .importPrivateKey:
                button.addTarget(self, action: #selector(importPrivateKey(_:)), for: .touchUpInside)
            case .importMnemonics:
                button.addTarget(self, action: #selector(importMnemonicPhrases(_:)), for: .touchUpInside)
            }
        case .general:
            importSecretButton?.removeFromSuperview()
            let actionView: TokenActionView
            if let view = tokenActionView, view.superview != nil {
                actionView = view
            } else {
                actionView = TokenActionView()
                actionView.actions = [.buy, .receive, .send, .trade]
                actionView.delegate = self
                actionStackView.insertArrangedSubview(actionView, at: 0)
                self.tokenActionView = actionView
            }
            actionView.badgeActions = {
                var actions: Set<TokenAction> = []
                if !BadgeManager.shared.hasViewed(identifier: .buy) {
                    actions.insert(.buy)
                }
                if !BadgeManager.shared.hasViewed(identifier: .trade) {
                    actions.insert(.trade)
                }
                return actions
            }()
        case .none:
            importSecretButton?.removeFromSuperview()
            tokenActionView?.removeFromSuperview()
        }
    }
    
    func load(tray: WalletOverview.Tray?) {
        switch tray {
        case let .watching(description):
            let view: WalletWatchingIndicatorView
            if let watchingIndicatorView {
                view = watchingIndicatorView
            } else {
                view = R.nib.walletWatchingIndicatorView(withOwner: nil)!
                view.button.addTarget(self, action: #selector(revealWatchingAddresses(_:)), for: .touchUpInside)
                view.label.text = description
                actionStackView.addArrangedSubview(view)
                view.snp.makeConstraints { make in
                    make.width.equalToSuperview()
                }
                watchingIndicatorView = view
            }
        case let .pendingDeposits(tokens, snapshots):
            assert(!snapshots.isEmpty)
            let view: WalletPendingDepositView
            if let pendingDepositView {
                view = pendingDepositView
            } else {
                view = R.nib.walletPendingDepositView(withOwner: nil)!
                view.button.removeTarget(self, action: nil, for: .touchUpInside)
                view.button.addTarget(self, action: #selector(revealPendingDeposits(_:)), for: .touchUpInside)
                actionStackView.addArrangedSubview(view)
                view.snp.makeConstraints { make in
                    make.width.equalToSuperview()
                }
                pendingDepositView = view
            }
            view.reload(tokens: tokens, snapshots: snapshots)
        case let .pendingTransactions(transactions):
            assert(!transactions.isEmpty)
            let view: WalletPendingDepositView
            if let pendingDepositView {
                view = pendingDepositView
            } else {
                view = R.nib.walletPendingDepositView(withOwner: nil)!
                view.button.removeTarget(self, action: nil, for: .touchUpInside)
                view.button.addTarget(self, action: #selector(revealPendingTransactions(_:)), for: .touchUpInside)
                actionStackView.addArrangedSubview(view)
                view.snp.makeConstraints { make in
                    make.width.equalToSuperview()
                }
                pendingDepositView = view
            }
            view.reload(pendingTransactions: transactions)
        case nil:
            watchingIndicatorView?.removeFromSuperview()
            pendingDepositView?.removeFromSuperview()
        }
    }
    
    @objc private func importPrivateKey(_ sender: UIButton) {
        delegate?.walletOverviewCell(self, didSelectImportAction: .importPrivateKey)
    }
    
    @objc private func importMnemonicPhrases(_ sender: UIButton) {
        delegate?.walletOverviewCell(self, didSelectImportAction: .importMnemonics)
    }
    
    @objc private func revealPendingDeposits(_ sender: Any) {
        delegate?.walletOverviewCellDidSelectPendingDeposits(self)
    }
    
    @objc private func revealPendingTransactions(_ sender: Any) {
        delegate?.walletOverviewCellDidSelectPendingTransactions(self)
    }
    
    @objc private func revealWatchingAddresses(_ sender: Any) {
        delegate?.walletOverviewCellDidSelectWatchingAddresses(self)
    }
    
}

extension WalletOverviewCell: TokenActionView.Delegate {
    
    func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction) {
        delegate?.walletOverviewCell(self, didSelectTokenAction: action)
        switch action {
        case .buy:
            BadgeManager.shared.setHasViewed(identifier: .buy)
            view.badgeActions.remove(.buy)
        case .trade:
            BadgeManager.shared.setHasViewed(identifier: .trade)
            view.badgeActions.remove(.trade)
        case .receive,  .send:
            break
        }
    }
    
}
