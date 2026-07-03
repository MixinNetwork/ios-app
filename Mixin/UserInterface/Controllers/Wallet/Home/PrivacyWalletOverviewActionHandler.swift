import UIKit
import MixinServices

final class PrivacyWalletOverviewActionHandler {
    
    private let tradeSource: UserOperationAnalytics.TradeSource
    
    private weak var responder: UIViewController?
    
    init(
        tradeSource: UserOperationAnalytics.TradeSource,
        responder: UIViewController?,
    ) {
        self.tradeSource = tradeSource
        self.responder = responder
    }
    
}

extension PrivacyWalletOverviewActionHandler: AssetChangeAccountRecoveryChecking {
    
    var accountRecoverCheckingResponder: UIViewController? {
        responder
    }
    
}

extension PrivacyWalletOverviewActionHandler: WalletActionHandler {
    
    func buy() {
        let selector = BuyTokenMethodSelectorViewController()
        selector.onSelected = { [weak responder, tradeSource] method in
            switch method {
            case .card:
                let buy = BuyTokenInputAmountViewController(wallet: .privacy)
                responder?.navigationController?.pushViewController(buy, animated: true)
            case .bankTransfer:
                _ = UrlWindow.checkApp(
                    userID: BotUserID.mixinCash,
                    action: .presentHomePage(additionalQueries: ["action": "add-cash-bank"])
                )
            }
            reporter.report(event: .buyStart, tags: ["wallet": "main", "source": tradeSource.rawValue])
        }
        responder?.present(selector, animated: true)
    }
    
    func receive() {
        reporter.report(event: .receiveStart, tags: ["wallet": "main", "source": tradeSource.rawValue])
        let selector = MixinTokenSelectorViewController(intent: .receive)
        selector.onSelected = { [weak responder] (token, location) in
            reporter.report(event: .receiveTokenSelect, tags: ["method": location.asEventMethod])
            let deposit = DepositViewController(token: token, switchingBetweenNetworks: true)
            responder?.navigationController?.pushViewController(deposit, animated: true)
        }
        withAccountRecoveryChecked { [weak responder] in
            responder?.present(selector, animated: true, completion: nil)
        }
    }
    
}

extension PrivacyWalletOverviewActionHandler: WalletOverviewCell.Delegate {
    
    func walletOverviewCell(_ cell: WalletOverviewCell, didSelectTokenAction action: TokenAction) {
        switch action {
        case .buy:
            buy()
        case .send:
            reporter.report(event: .sendStart, tags: ["wallet": "main", "source": tradeSource.rawValue])
            let selector = MixinTokenSelectorViewController(intent: .send)
            selector.onSelected = { [weak responder] (token, location) in
                reporter.report(event: .sendTokenSelect, tags: ["method": location.asEventMethod])
                let receiver = MixinTokenReceiverViewController(token: token)
                responder?.navigationController?.pushViewController(receiver, animated: true)
            }
            withAccountRecoveryChecked { [weak responder] in
                responder?.present(selector, animated: true, completion: nil)
            }
        case .receive:
            receive()
        case .trade:
            UserOperationAnalytics.tradeSource = tradeSource
            let trade = TradeViewController(
                wallet: .privacy,
                trading: nil,
                sendAssetID: nil,
                receiveAssetID: nil,
                referral: nil
            )
            guard let trade else {
                return
            }
            withAccountRecoveryChecked { [weak responder] in
                responder?.navigationController?.pushViewController(trade, animated: true)
            }
        }
    }
    
    func walletOverviewCell(_ cell: WalletOverviewCell, didSelectImportAction action: WalletOverview.ImportSecretAction) {
        assertionFailure("No importing in privacy wallet")
    }
    
    func walletOverviewCellDidSelectPendingDeposits(_ cell: WalletOverviewCell) {
        let transactionHistory = MixinTransactionHistoryViewController(type: .pending)
        responder?.navigationController?.pushViewController(transactionHistory, animated: true)
        reporter.report(event: .allTransactions, tags: ["source": tradeSource.rawValue])
    }
    
    func walletOverviewCellDidSelectPendingTransactions(_ cell: WalletOverviewCell) {
        assertionFailure("No pending tx in privacy wallet")
    }
    
    func walletOverviewCellDidSelectWatchingAddresses(_ cell: WalletOverviewCell) {
        assertionFailure("No watching address in privacy wallet")
    }
    
}
